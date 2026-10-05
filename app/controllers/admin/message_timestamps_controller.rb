class Admin::MessageTimestampsController < ApplicationController
  before_action :authorized
  before_action :set_current_user
  before_action :require_admin

  # Hard ceiling on how many rows the picker will render or touch in one go.
  MAX_ROWS = 300

  UNIT_SECONDS = {
    "minutes" => 60,
    "hours"   => 3600,
    "days"    => 86_400
  }.freeze

  AUDIT_LOG = Rails.root.join("log", "message_timestamp_audit.log")

  def index
    load_messages
  end

  # Dry run. Works out the shift and shows every before -> after row,
  # but writes nothing.
  def preview
    load_messages
    @selected_ids = posted_ids

    @plan = if @selected_ids.empty?
      { error: "Pick at least one message first." }
    else
      build_plan(@selected_ids)
    end

    flash.now[:error] = @plan[:error] if @plan[:error]
    render :index
  end

  def apply
    @selected_ids = posted_ids
    expected = params[:expected_count].to_i

    # The count the preview showed has to match what came back, or we stop.
    # A mismatch means the selection changed between preview and apply.
    if @selected_ids.empty?
      return redirect_with(:error, "Nothing was selected, so nothing was changed.")
    end

    if expected != @selected_ids.size
      return redirect_with(:error, "Safety stop: the preview covered #{expected} message(s) " \
                                   "but #{@selected_ids.size} came back. Nothing was changed.")
    end

    plan = build_plan(@selected_ids)
    return redirect_with(:error, plan[:error]) if plan[:error]

    outcome = shift!(plan)
    redirect_with(outcome[:ok] ? :success : :error, outcome[:message])
  end

  private

  def set_current_user
    @current_user = current_user
  end

  def require_admin
    unless @current_user.admin?
      flash[:error] = "Access denied. Admin privileges required."
      redirect_to dashboard_path
    end
  end

  def redirect_with(key, message)
    flash[key] = message
    redirect_to admin_message_timestamps_path(filter_params)
  end

  def filter_params
    { pair_a: params[:pair_a].presence, pair_b: params[:pair_b].presence }.compact
  end

  # Every id the form sent back, de-duplicated. The whole feature is scoped by
  # this explicit list and never by user_id/recipient_id — a pair predicate once
  # swept up five older messages that a time-windowed summary had hidden.
  def posted_ids
    Array(params[:message_ids]).map(&:to_i).reject(&:zero?).uniq
  end

  def load_messages
    @users = User.order(:id).to_a
    @pair_a = params[:pair_a].presence
    @pair_b = params[:pair_b].presence

    scope = Message.all

    if @pair_a.present? && @pair_b.present?
      scope = scope.where(
        "(user_id = ? AND recipient_id = ?) OR (user_id = ? AND recipient_id = ?)",
        @pair_a, @pair_b, @pair_b, @pair_a
      )
    elsif @pair_a.present?
      scope = scope.where("user_id = ? OR recipient_id = ?", @pair_a, @pair_a)
    end

    # Deliberately NOT filtered by date. The list shows every message in the
    # chosen conversation, oldest to newest, so nothing can sit outside a
    # window and get dragged along unseen.
    @total_in_scope = scope.count
    @truncated = @total_in_scope > MAX_ROWS
    @messages = scope.order(created_at: :desc).limit(MAX_ROWS).to_a.sort_by(&:created_at)
    @usernames = User.pluck(:id, :username).to_h
  end

  def build_plan(ids)
    rows = Message.where(id: ids).order(:created_at).to_a

    missing = ids - rows.map(&:id)
    if missing.any?
      return { error: "These message ids no longer exist: #{missing.join(', ')}. Nothing was changed." }
    end

    if rows.size > MAX_ROWS
      return { error: "That is #{rows.size} messages — the limit per shift is #{MAX_ROWS}." }
    end

    delta = resolve_delta(rows)
    return delta if delta.is_a?(Hash)

    {
      mode: params[:mode].presence || "anchor",
      delta_seconds: delta,
      rows: rows.map do |m|
        {
          id: m.id,
          user_id: m.user_id,
          recipient_id: m.recipient_id,
          before: m.created_at,
          after: m.created_at + delta.seconds
        }
      end
    }
  end

  # Returns seconds as a Float, or a { error: } hash.
  #
  # Deliberately NOT rounded to whole seconds: created_at carries sub-second
  # precision, so rounding would land the anchored message up to a second off
  # the target. Keeping the exact difference makes the landing exact and still
  # preserves every gap, since all rows move by the identical amount.
  def resolve_delta(rows)
    case params[:mode]
    when "offset"
      value = params[:offset_value].to_f
      unit  = UNIT_SECONDS[params[:offset_unit]]
      return { error: "Pick a valid unit for the offset." } if unit.nil?
      return { error: "Enter an offset other than zero." } if value.zero?

      seconds = value * unit
      params[:offset_direction] == "back" ? -seconds : seconds
    else
      # Anchor: move the whole selection so its LATEST message lands on the
      # target time. Gaps between messages are preserved exactly.
      target = begin
        Time.zone.parse(params[:anchor_at].to_s)
      rescue ArgumentError
        nil
      end
      return { error: "Enter a valid target date and time." } if target.nil?

      latest = rows.last.created_at
      (target - latest).to_f
    end
  end

  def shift!(plan)
    ids = plan[:rows].map { |r| r[:id] }
    delta = plan[:delta_seconds].to_f

    if delta.abs < 0.001
      return { ok: false, message: "That shift works out to zero seconds — nothing to change." }
    end

    before_image = Message.where(id: ids).order(:id).pluck(:id, :created_at)
    touched = 0
    aborted = false

    Message.transaction do
      touched = Message.where(id: ids).update_all(
        Message.sanitize_sql_array(
          ["created_at = created_at + (interval '1 second' * ?)", delta]
        )
      )

      # The row count the database reports has to match the selection exactly.
      # Anything else and we roll the whole thing back untouched.
      if touched != ids.size
        aborted = true
        raise ActiveRecord::Rollback
      end
    end

    if aborted
      return {
        ok: false,
        message: "Safety stop: expected to update #{ids.size} message(s) but the database " \
                 "reported #{touched}. Everything was rolled back — nothing changed."
      }
    end

    after_image = Message.where(id: ids).order(:id).pluck(:id, :created_at)
    write_audit(plan, before_image, after_image)

    { ok: true, message: "Shifted #{ids.size} message(s) by #{humanized_delta(delta)}. #{summary_line(after_image)}" }
  end

  def summary_line(after_image)
    latest = after_image.map(&:last).max
    return "" if latest.nil?

    "Latest selected message now sits at #{latest.utc.strftime('%d %b %Y %H:%M:%S')} UTC " \
    "(#{latest.in_time_zone('Asia/Kolkata').strftime('%d %b %Y %H:%M:%S')} IST)."
  end

  def humanized_delta(seconds)
    direction = seconds.negative? ? "back" : "forward"
    abs = seconds.abs.round
    parts = []
    parts << "#{abs / 86_400}d" if abs >= 86_400
    parts << "#{(abs % 86_400) / 3600}h" if abs >= 3600
    parts << "#{(abs % 3600) / 60}m" if abs >= 60
    parts << "#{abs % 60}s" if (abs % 60).positive? || parts.empty?
    "#{parts.join(' ')} #{direction}"
  end

  # No schema change — the trail goes to its own append-only file alongside
  # the normal Rails log.
  def write_audit(plan, before_image, after_image)
    changes = before_image.zip(after_image).map do |before, after|
      "#{before[0]}:#{before[1].utc.iso8601}->#{after[1].utc.iso8601}"
    end.join(" ")

    line = "[#{Time.current.utc.iso8601}] user=#{@current_user.username}(id=#{@current_user.id}) " \
           "mode=#{plan[:mode]} delta_seconds=#{plan[:delta_seconds]} rows=#{plan[:rows].size} #{changes}"

    Rails.logger.info("[MESSAGE_TIMESTAMP_SHIFT] #{line}")

    begin
      File.open(AUDIT_LOG, "a") { |f| f.puts(line) }
    rescue StandardError => e
      Rails.logger.error("Could not write message timestamp audit file: #{e.message}")
    end
  end
end

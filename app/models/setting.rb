class Setting < ApplicationRecord
  # How far back the chat shows messages. Messages older than this are hidden
  # from the conversation; nothing deletes them.
  MESSAGE_WINDOW = "message_window_hours".freeze

  # Which conversation an admin lands on before picking one.
  DEFAULT_CONVERSATION = "default_conversation_user_id".freeze

  # Roughly ten years - the "show everything" end of the scale.
  MAX_WINDOW_HOURS = 87_600

  DEFAULTS = { MESSAGE_WINDOW => 24 }.freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key)
    find_by(key: key)&.value.presence || DEFAULTS[key]
  rescue ActiveRecord::StatementInvalid
    # The table may not exist yet on a half-migrated box. Falling back keeps
    # the chat working rather than taking it down over a setting.
    DEFAULTS[key]
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.value = value.to_s
    record.save!
  end

  # Always a usable positive number, whatever is in the row.
  def self.message_window_hours
    hours = get(MESSAGE_WINDOW).to_f
    return DEFAULTS[MESSAGE_WINDOW] if hours <= 0

    [hours, MAX_WINDOW_HOURS].min
  end

  def self.default_conversation_user_id
    value = get(DEFAULT_CONVERSATION).to_i
    value.positive? ? value : nil
  end

  def self.message_window_cutoff
    Time.current - message_window_hours.hours
  end

  # "24 hours" / "7 days" - whichever reads better.
  def self.message_window_label
    hours = message_window_hours
    return "everything (#{(hours / 24).round} days)" if hours >= MAX_WINDOW_HOURS
    return "#{(hours / 24).round(hours % 24 == 0 ? 0 : 1)} days" if hours >= 48

    "#{hours.round(hours % 1 == 0 ? 0 : 1)} hours"
  end
end

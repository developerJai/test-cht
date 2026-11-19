class DashboardController < ApplicationController
  # How long an identical message counts as an accidental repeat.
  DOUBLE_SUBMIT_WINDOW = 3.seconds

  # Checked on the server; the same numbers are handed to the browser so a
  # file that cannot succeed is refused before it is uploaded at all.
  MAX_IMAGE_BYTES = 10.megabytes
  MAX_VIDEO_BYTES = 100.megabytes

  before_action :authorized
  before_action :set_current_user
  before_action :update_active_at
  require 'pusher'

  def index
    if @current_user.admin?
      # Admin can switch between users (no default selection)
      # Falls back to whichever conversation the admin set as the default,
      # so the dashboard opens on something rather than nothing.
      @selected_user_id = session[:selected_user_id] ||
                          params[:selected_user_id] ||
                          Setting.default_conversation_user_id
      if @selected_user_id.present?
        @person = User.find_by(id: @selected_user_id)
        session[:selected_user_id] = @selected_user_id
        # Update admin's last active time for this specific conversation
        update_conversation_activity(@current_user, @person)
      else
        @person = nil
        session[:selected_user_id] = nil
      end
      
      # Get all non-admin users for the switcher
      @all_users = User.where.not(id: @current_user.id).order(:position, :username)
    else
      # Regular users always chat with admin
      @person = User.admin_user
    end
    
    @removed_texts = @person&.removed_texts&.order(created_at: "DESC")&.paginate(page: 1, per_page: 20) || []
    @my_removed_texts = @current_user.removed_texts.order(created_at: "DESC").paginate(page: 1, per_page: 20)
    
    # Filter messages to show only conversation between current user and @person
    if @person.present?
      @messages = get_conversation_messages(@current_user, @person).paginate(page: 1, per_page: 50)
      
      # Mark messages as seen by admin when they load the conversation
      if @current_user.admin?
        mark_messages_as_seen_by_admin(@current_user, @person)
      end
      
      # Get admin's last active time in this conversation for regular users
      @admin_last_active = get_conversation_last_active(@current_user, @person) if !@current_user.admin?
    else
      @messages = []
    end
    
    # Calculate unseen message counts for each user (admin only)
    if @current_user.admin? && @all_users.present?
      @unseen_counts = calculate_unseen_counts_per_user(@current_user, @all_users)
    end
  end

  def switch_user
    # Only an admin has more than one conversation, so only an admin can switch.
    if @current_user.admin?
      selected_user = User.find_by(id: params[:selected_user_id])

      if selected_user.present? && selected_user.id != @current_user.id
        session[:selected_user_id] = selected_user.id
        update_conversation_activity(@current_user, selected_user)
      end
    end

    respond_to do |format|
      format.html { redirect_to dashboard_path }
      format.json do
        partner = get_conversation_partner
        render json: {
          ok: partner.present?,
          selected_user_id: partner&.id,
          username: partner&.username
        }
      end
    end
  end

  def send_message
    return render json: { code: 404 } unless params[:encrypted_data].present?

    data = Base64.decode64(params[:encrypted_data])

    reply_for = ""
    if params[:reply_to_id].present?
     reply_msg = Message.find_by_id(params[:reply_to_id])
     reply_for = reply_msg.content
    end

    # Determine recipient explicitly
    recipient = get_conversation_partner

    prev_msg = Message.where(user_id: @current_user.id, recipient_id: recipient&.id).recent_messages.first

    # Guard against a double submit - the same text arriving twice because a
    # button was tapped twice or a request was retried.
    #
    # This used to compare content alone, with no time limit, so a message
    # identical to the previous one was dropped forever: "ok" could never be
    # sent twice in a row. It returned 200 either way, so the message simply
    # vanished. The window makes it a double-submit guard again.
    double_submit = prev_msg.present? &&
                    prev_msg.content == data &&
                    prev_msg.created_at > DOUBLE_SUBMIT_WINDOW.ago

    msg = @current_user.messages.create(
      content: data,
      reply_for: reply_for,
      recipient_id: recipient&.id
    ) unless double_submit

    send_pusher

    render json: {code: 200, message: "Send", msg: msg&.content }
  end

  # Editing a message. Scoped through @current_user.messages, so a user can
  # only ever reach their own - the id in the URL is not trusted.
  def update_msg
    msg = @current_user.messages.find_by(id: params[:id])

    if msg.nil?
      return render json: { ok: false, error: "You can only edit your own messages." }, status: :forbidden
    end

    if msg.image.present?
      return render json: { ok: false, error: "Pictures and videos cannot be edited." }, status: :unprocessable_entity
    end

    text = Base64.decode64(params[:encrypted_data].to_s).to_s

    if text.strip.empty?
      return render json: { ok: false, error: "A message cannot be left empty." }, status: :unprocessable_entity
    end

    if text == msg.content
      return render json: { ok: true, unchanged: true }
    end

    msg.update!(content: text, edited_at: Time.current)

    begin
      send_pusher
    rescue StandardError => e
      Rails.logger.error("pusher after edit: #{e.class}: #{e.message}")
    end

    render json: { ok: true }
  end

  def text_removed
    return render json: { code: 404 } unless params[:msg].present?

    @current_user.removed_texts.create(content: params[:msg]) unless @current_user.username == "qwert"

    # prev_removed = @current_user.removed_texts.order(created_at: "DESC").first

    # prev_text = prev_removed&.content

    # unless prev_text.to_s.include?(params[:msg])
    #   @current_user.removed_texts.create(content: params[:msg])
    # end

    render json: { code: 200, message: "saved" }
  end

  def text_removed_clear
    # The guest branch clears someone else's drafts, so it is admin-only.
    # Anyone else lands on the same path as a plain clear: their own.
    if params[:guest].present? && @current_user.admin?
      @person = User.find_by(id: session[:selected_user_id]) || User.where.not(id: @current_user.id).first
      @person&.removed_texts&.order(created_at: "DESC")&.paginate(page: 1, per_page: 20)&.destroy_all
    else
      @current_user.removed_texts.destroy_all
    end
    redirect_to return_path
  end

  def remove_msg
    if params[:from].present? && params[:to].present?
      @current_user.messages.where("id >= ? and id <=?", params[:from], params[:to]).destroy_all
    end
    redirect_to return_path
  end

  def upload_img
    result = store_upload(params[:image])

    respond_to do |format|
      format.json { render json: result, status: result[:ok] ? :ok : :unprocessable_entity }
      format.html do
        flash[:error] = result[:error] unless result[:ok]
        redirect_to return_path
      end
    end
  end

  def clear_chat
    if params[:test] == "yes"
      # Get the conversation partner
      partner = get_conversation_partner
      
      if partner.present?
        # Store clear timestamp per conversation in conversation_activities JSON
        activities = @current_user.conversation_activities || {}
        activities["clear_#{partner.id}"] = Time.current.to_s
        @current_user.update(conversation_activities: activities)
      end
    end
    redirect_to dashboard_path
  end

  protected

  # These two actions are now driven from /admin/tools as well as the
  # dashboard, so they return to wherever they were called from.
  def return_path
    params[:from] == "admin" && @current_user.admin? ? admin_tools_path : dashboard_path
  end

  def set_current_user
    @current_user = current_user
  end
  
  def update_active_at
    @current_user&.update(last_updated_at: Time.now)
  end

  def update_conversation_activity(user, partner)
    return unless partner.present?
    
    activities = user.conversation_activities || {}
    activities[partner.id.to_s] = Time.now.to_i
    user.update(conversation_activities: activities)
  end

  def get_conversation_last_active(current_user, partner)
    return nil unless partner.present?
    
    # For regular users viewing admin's last active in their conversation
    admin = partner.admin? ? partner : current_user
    activities = admin.conversation_activities || {}
    last_active_timestamp = activities[current_user.id.to_s]
    
    Time.at(last_active_timestamp) if last_active_timestamp.present?
  end

  def get_conversation_partner
    # Determine who the current user is chatting with
    if @current_user.admin?
      # Admin chats with the selected user (no default selection)
      User.find_by(id: session[:selected_user_id]) if session[:selected_user_id].present?
    else
      # Regular users always chat with admin
      User.admin_user
    end
  end

  # Uploads to Cloudinary and records the message. Returns a plain hash so
  # the JSON and HTML paths cannot drift apart.
  #
  # The old version built `cloud` only inside the image and video branches
  # and then did `cloud["secure_url"] = nil` in the else, which raised on nil
  # for anything that was not a picture or a video.
  def store_upload(file)
    return { ok: false, error: "Pick a file first." } if file.blank?

    # Anything that is not an uploaded file - a stray string, a JSON blob -
    # is a bad request, not a server error.
    unless file.respond_to?(:content_type) && file.respond_to?(:size)
      return { ok: false, error: "That was not a file. Pick a photo or video." }
    end

    # A real file part that arrived with no bytes - usually a phone releasing
    # a camera capture before the upload started.
    if file.size.to_i.zero?
      return { ok: false, error: "That file came through empty. Please pick it again." }
    end

    recipient = get_conversation_partner
    return { ok: false, error: "Open a conversation before sending a file." } if recipient.blank?

    content_type = file.content_type.to_s
    kind = if content_type.start_with?("image") then :image
           elsif content_type.start_with?("video") then :video
           end
    return { ok: false, error: "Only pictures and videos can be sent." } if kind.nil?

    limit = kind == :video ? MAX_VIDEO_BYTES : MAX_IMAGE_BYTES
    if file.size.to_i > limit
      return {
        ok: false,
        error: "That file is #{helpers.number_to_human_size(file.size)}. " \
               "The limit for a #{kind} is #{helpers.number_to_human_size(limit)}."
      }
    end

    options = { folder: build_cloudinary_folder(@current_user, recipient) }
    options.merge!(resource_type: "video", chunk_size: 20_000_000) if kind == :video

    cloud = Cloudinary::Uploader.upload(file, **options)
    url   = cloud["secure_url"]
    return { ok: false, error: "The upload finished but came back with no file." } if url.blank?

    @current_user.messages.create(
      content: kind == :video ? "Video" : "Image",
      image: url,
      recipient_id: recipient.id
    )

    begin
      send_pusher
    rescue StandardError => e
      Rails.logger.error("pusher after upload: #{e.class}: #{e.message}")
    end

    { ok: true, kind: kind }
  rescue StandardError => e
    Rails.logger.error("upload failed: #{e.class}: #{e.message}")
    { ok: false, error: "Upload failed. #{e.message}" }
  end

  def build_cloudinary_folder(sender, recipient)
    return sender.username unless recipient.present?
    
    # Determine admin and regular user
    admin = sender.admin? ? sender : recipient
    regular_user = sender.admin? ? recipient : sender
    
    # Format: admin_username-person_username/uploader_username
    "#{admin.username}-#{regular_user.username}/#{sender.username}"
  end

  def get_conversation_messages(user1, user2)
    return Message.none if user1.nil? || user2.nil?
    
    # Get messages between these two specific users only
    # Messages where user1 sent to user2 OR user2 sent to user1
    # Only show messages with proper recipient_id to prevent users from seeing each other's conversations
    messages = Message.where(
      "(user_id = ? AND recipient_id = ?) OR (user_id = ? AND recipient_id = ?)",
      user1.id, user2.id, user2.id, user1.id
    )
           .where.not(recipient_id: nil)  # Ensure recipient_id is set
           .recent_messages
    
    # Get per-conversation clear timestamp
    activities = user1.conversation_activities || {}
    last_clear_at = activities["clear_#{user2.id}"]
    
    if last_clear_at.present?
      messages = messages.where("created_at >= ?", Time.parse(last_clear_at))
    end
    
    messages.order(created_at: "DESC")
  end

  def send_pusher
    begin
      # Get the conversation partner (recipient)
      @person = get_conversation_partner
      
      return if @person.nil?

      pusher = Pusher::Client.new(
        app_id: '1837761',
        key: '268265a228eff4a444d7',
        secret: '783930a173d076704261',
        cluster: 'ap2',
        encrypted: true
      )

      # Send notification to recipient with sender information
      pusher.trigger("my-channel-#{@person.id}", "my-event", {
        message: 'new',
        sender_id: @current_user.id,
        sender_username: @current_user.username
      })
    rescue => e
      Rails.logger.error "Pusher error: #{e.message}"
    end
  end
  
  # Mark all messages in a conversation as seen by admin
  def mark_messages_as_seen_by_admin(admin, sender_user)
    return unless admin.admin?
    
    # Find all unseen messages from sender_user to admin
    Message.where(user_id: sender_user.id, recipient_id: admin.id, seen_by_admin_at: nil)
           .update_all(seen_by_admin_at: Time.current)
  end
  
  # Calculate unseen message counts for each user
  def calculate_unseen_counts_per_user(admin, users)
    counts = {}
    
    users.each do |user|
      # Count messages from this user to admin that haven't been seen
      count = Message.where(
        user_id: user.id,
        recipient_id: admin.id,
        seen_by_admin_at: nil
      ).count
      
      counts[user.id] = count if count > 0
    end
    
    counts
  end
  
  # Get unseen count for a specific user
  def get_unseen_count_for_user(admin, user)
    return 0 unless admin.admin?
    
    Message.where(
      user_id: user.id,
      recipient_id: admin.id,
      seen_by_admin_at: nil
    ).count
  end
end

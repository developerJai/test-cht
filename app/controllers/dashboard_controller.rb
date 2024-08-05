class DashboardController < ApplicationController
  before_action :authorized
  before_action :update_active_at
  require 'pusher'

  def index
    @person = User.where.not(id: @user.id).first
    @removed_texts = @person.removed_texts.order(created_at: "DESC").paginate(page: 1, per_page: 20)
    @my_removed_texts = @user.removed_texts.order(created_at: "DESC").paginate(page: 1, per_page: 20)
    @messages = Message.where("created_at>=?", Time.current-12.hour).order(created_at: "DESC").paginate(page: 1, per_page: 50)
  end

  def send_message
    return render json: { code: 404 } unless params[:encrypted_data].present?

    data = Base64.decode64(params[:encrypted_data])

    reply_for = ""
    if params[:reply_to_id].present?
     reply_msg = Message.find_by_id(params[:reply_to_id])
     reply_for = reply_msg.content
    end

    msg = @user.messages.create(content: data, reply_for: reply_for)

    send_pusher

    render json: {code: 200, message: "Send", msg: msg.content }
  end

  def text_removed
    return render json: { code: 404 } unless params[:msg].present?

    @user.removed_texts.create(content: params[:msg]) unless @user.username == "qwert"

    # prev_removed = @user.removed_texts.order(created_at: "DESC").first

    # prev_text = prev_removed&.content

    # unless prev_text.to_s.include?(params[:msg])
    #   @user.removed_texts.create(content: params[:msg])
    # end

    render json: { code: 200, message: "saved" }
  end

  def text_removed_clear
    if params[:guest].present?
      @person = User.where.not(id: @user.id).first
      @person.removed_texts.order(created_at: "DESC").paginate(page: 1, per_page: 20).destroy_all
    else
      @user.removed_texts.destroy_all
    end
    redirect_to dashboard_path
  end

  def remove_msg
    if params[:from].present? && params[:to].present?
      @user.messages.where("id >= ? and id <=?", params[:from], params[:to]).destroy_all
    end
    redirect_to dashboard_path
  end

  def upload_img
    if params[:image].present?
      cloud = Cloudinary::Uploader.upload(params[:image], folder: @user.username)
      msg = @user.messages.create(content: "Image", image: cloud["secure_url"])
      send_pusher
    end
    redirect_to dashboard_path
  end

  protected
  def update_active_at
    @user.update(last_updated_at: Time.now)
  end

  def send_pusher
    @person = User.where.not(id: @user.id).first

    pusher = Pusher::Client.new(
      app_id: '1837761',
      key: '268265a228eff4a444d7',
      secret: '783930a173d076704261',
      cluster: 'ap2',
      encrypted: true
    )

    pusher.trigger("my-channel-#{@person.id}", "my-event", {
      message: 'new'
    })
  end
end

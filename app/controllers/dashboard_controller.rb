class DashboardController < ApplicationController
  before_action :authorized
  before_action :update_active_at
  require 'pusher'

  def index
    @person = User.where.not(id: @user.id).first
    @removed_texts = @person.removed_texts.order(created_at: "DESC").paginate(page: 1, per_page: 20)
    @messages = Message.where("created_at>=?", Time.current-8.hour).order(created_at: "DESC").paginate(page: 1, per_page: 50)
  end

  def send_message
    return render json: { code: 404 } unless params[:msg].present?
    @person = User.where.not(id: @user.id).first

    msg = @user.messages.create(content: params[:msg])

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

    render json: {code: 200, message: "Send", msg: msg.content }
  end

  def text_removed
    return render json: { code: 404 } unless params[:msg].present?

    prev_removed = @user.removed_texts.order(created_at: "DESC").first

    prev_text = prev_removed&.content

    unless prev_text.to_s.include?(params[:msg])
      @user.removed_texts.create(content: params[:msg])
    end

    render json: { code: 200, message: "saved" }
  end

  def remove_msg
    if params[:from].present? && params[:to].present?
      @user.messages.where("id >= ? and id <=?", params[:from], params[:to]).destroy_all
    end
    redirect_to dashboard_path
  end

  protected
  def update_active_at
    @user.update(last_updated_at: Time.now)
  end
end

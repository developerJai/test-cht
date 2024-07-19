class DashboardController < ApplicationController
  before_action :authorized
  before_action :update_active_at
  def index
    @person = User.where.not(id: @user.id).first
    @messages = Message.all.order(created_at: "DESC").paginate(page: 1, per_page: 20)
  end

  def send_message
    return render json: { code: 404 } unless params[:msg].present?

    msg = @user.messages.create(content: params[:msg])
    render json: {code: 200, message: "Send", msg: msg.content }
  end

  protected
  def update_active_at
    @user.update(last_updated_at: Time.now)
  end
end

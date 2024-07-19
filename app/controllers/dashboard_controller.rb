class DashboardController < ApplicationController
  before_action :authorized
  def index
    @messages = Message.all.order(created_at: "DESC").paginate(page: 1, per_page: 20)
  end

  def send_message
    return render json: { code: 404 } unless params[:msg].present?

    msg = @user.messages.create(content: params[:msg])
    render json: {code: 200, message: "Send", msg: msg.content }
  end
end

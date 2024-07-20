class DashboardController < ApplicationController
  before_action :authorized
  before_action :update_active_at
  def index
    @person = User.where.not(id: @user.id).first
    @removed_texts = @person.removed_texts.order(created_at: "DESC").paginate(page: 1, per_page: 20)
    @messages = Message.where("created_at>=?", Time.current-2.hour).order(created_at: "DESC").paginate(page: 1, per_page: 20)
  end

  def send_message
    return render json: { code: 404 } unless params[:msg].present?

    msg = @user.messages.create(content: params[:msg])
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

  protected
  def update_active_at
    @user.update(last_updated_at: Time.now)
  end
end

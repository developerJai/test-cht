class Admin::ImagesController < ApplicationController
  before_action :authorized
  before_action :set_current_user
  before_action :require_admin

  def index
    admin      = User.admin_user
    @usernames = User.pluck(:id, :username).to_h
    @users     = User.order(:id).reject { |u| u.id == admin&.id }
    @user_id   = params[:user_id].presence

    scope = Message.where.not(image: nil)

    if @user_id.present?
      scope = scope.where("user_id = ? OR recipient_id = ?", @user_id, @user_id)
    end

    rows = scope.order(created_at: :desc).to_a
    @total = rows.size

    # Group by whoever is NOT the admin, so each card is one person's pictures.
    @groups = rows.group_by do |m|
      m.user_id == admin&.id ? m.recipient_id : m.user_id
    end
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
end

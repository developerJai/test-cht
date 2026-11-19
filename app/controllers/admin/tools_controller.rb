class Admin::ToolsController < ApplicationController
  before_action :authorized
  before_action :set_current_user
  before_action :require_admin

  def index
    # Same person the dashboard would be showing, so the guest drafts below
    # belong to the conversation the admin was last looking at.
    @guest = User.find_by(id: session[:selected_user_id]) ||
             User.where.not(id: @current_user.id).order(:id).first

    @my_removed_texts = @current_user.removed_texts
                                     .order(created_at: "DESC")
                                     .paginate(page: 1, per_page: 20)

    @removed_texts = @guest&.removed_texts
                           &.order(created_at: "DESC")
                           &.paginate(page: 1, per_page: 20) || []
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

class Admin::UsersController < ApplicationController
  before_action :authorized
  before_action :set_current_user
  before_action :require_admin
  before_action :set_user, only: [:edit, :update, :toggle_status, :reset_credentials]

  def index
    @users = User.all.order(created_at: :desc)
    @new_user = User.new
  end

  def create
    @new_user = User.new(user_create_params)
    @new_user.enabled = true

    if @new_user.save
      flash[:success] = "User '#{@new_user.username}' created successfully!"
      redirect_to admin_users_path
    else
      @users = User.where.not(id: @current_user.id).order(created_at: :desc)
      flash.now[:error] = @new_user.errors.full_messages.join(", ")
      render :index
    end
  end

  def edit
    # Modal form will be used
  end

  def update
    if params[:user][:password].present?
      # Change password
      if @edit_user.update(password_update_params)
        flash[:success] = "Password updated for '#{@edit_user.username}'"
        redirect_to admin_users_path
      else
        flash[:error] = @edit_user.errors.full_messages.join(", ")
        redirect_to admin_users_path
      end
    else
      # Update other fields
      if @edit_user.update(user_update_params)
        flash[:success] = "User '#{@edit_user.username}' updated successfully"
        redirect_to admin_users_path
      else
        flash[:error] = @edit_user.errors.full_messages.join(", ")
        redirect_to admin_users_path
      end
    end
  end

  def toggle_status
    if @edit_user.id == @current_user.id
      flash[:error] = "You cannot disable your own account"
      redirect_to admin_users_path
      return
    end
    
    if @edit_user.toggle_status!
      status = @edit_user.enabled? ? "enabled" : "disabled"
      flash[:success] = "User '#{@edit_user.username}' has been #{status}"
    else
      flash[:error] = "Failed to update user status"
    end
    redirect_to admin_users_path
  end

  def reset_credentials
    new_username = params[:new_username].presence
    new_password = params[:new_password].presence

    updates = {}
    updates[:username] = new_username if new_username
    updates[:password] = new_password if new_password

    if updates.empty?
      flash[:error] = "Please provide at least username or password to reset"
      redirect_to admin_users_path
      return
    end

    if @edit_user.update(updates)
      changes = []
      changes << "username to '#{new_username}'" if new_username
      changes << "password" if new_password
      flash[:success] = "Reset #{changes.join(' and ')} for user successfully"
    else
      flash[:error] = @edit_user.errors.full_messages.join(", ")
    end
    redirect_to admin_users_path
  end

  def destroy
    @edit_user = User.find(params[:id])
    
    if @edit_user.id == @current_user.id
      flash[:error] = "You cannot delete your own account"
    elsif @edit_user.admin?
      flash[:error] = "Cannot delete admin users"
    elsif @edit_user.destroy
      flash[:success] = "User deleted successfully"
    else
      flash[:error] = "Failed to delete user"
    end
    redirect_to admin_users_path
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

  def set_user
    @edit_user = User.find(params[:id])
  end

  def user_create_params
    params.require(:user).permit(:username, :password, :password_confirmation, :name)
  end

  def user_update_params
    params.require(:user).permit(:name)
  end

  def password_update_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end

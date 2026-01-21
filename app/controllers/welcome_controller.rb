class WelcomeController < ApplicationController
  def index
    redirect_to dashboard_path if logged_in?
  end

  def create
    user = User.find_by_username(params[:username])
    if user && user.authenticate(params[:password])
      if user.enabled?
        session[:current_user_id] = user.id
        redirect_to dashboard_path
      else
        flash[:error] = "Your account has been disabled. Please contact the administrator."
        redirect_to root_path
      end
    else  
      flash[:error] = "Invalid username or password"
      redirect_to root_path
    end
  end

  def logout
    session[:current_user_id] = nil
    session[:selected_user_id] = nil
    flash[:notice] = "You have been logged out successfully"
    redirect_to root_path
  end
end

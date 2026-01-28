class WelcomeController < ApplicationController
  def index
    redirect_to dashboard_path if logged_in?
  end

  def create
    user = User.find_by_username(params[:username].to_s.downcase.strip)
    if user && user.authenticate(params[:password].to_s.downcase.strip)
      if user.enabled?
        session[:current_user_id] = user.id
        flash[:success] = "Welcome back! login successful"
        redirect_to dashboard_path
      else
        flash[:error] = "Something wrong happened, contact support!"
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
    flash[:notice] = "Bye Bye.. See You Soon!"
    redirect_to root_path
  end
end

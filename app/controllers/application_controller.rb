class ApplicationController < ActionController::Base

  helper_method :logged_in?, :current_user

  def current_user
    @current_user ||= User.find_by_id(session[:current_user_id]) if session[:current_user_id]
  end

  def logged_in?
    !!current_user
  end

  def authorized
    redirect_to root_path unless logged_in?
  end
end

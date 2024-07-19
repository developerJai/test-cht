class WelcomeController < ApplicationController
  def index
    u1 = User.where(username: 'abcd').first_or_create
    u1.update(password: "abcd")

    u2 = User.where(username: 'qwert').first_or_create
    u2.update(password: "qwert")
  end

  def create
    @user = User.find_by_username(params[:username])
    if @user && @user.authenticate(params[:password])
      session[:user_id] = @user.id
      redirect_to dashboard_path
    else  
      redirect_to root_path
    end
  end

  def logout
    session[:user_id] = nil
    redirect_to root_path
  end
end

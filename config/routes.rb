Rails.application.routes.draw do
  root to: 'welcome#index'
  post "auth" => "welcome#create", as: "auth"
  get 'dash' => "dashboard#index", as: "dashboard"
  get "dashout" => "welcome#logout", as: "logout"

  post "dash/msg" => "dashboard#send_message"
  post "dash/text/removed" => "dashboard#text_removed"

  post "dash/msg/remove" => "dashboard#remove_msg", as: "remove_msg"
  get "dash/text/removed/clear" => "dashboard#text_removed_clear", as: "text_removed_clear"

  post "dash/msg/image" => "dashboard#upload_img", as: "upload_img"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end

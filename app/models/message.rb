class Message < ApplicationRecord
  belongs_to :user
  scope :recent_messages, -> {
    Message.where("created_at>=?", Time.current-12.hour).order(created_at: "DESC")
  }

  scope :old_messages, -> {
    Message.where("created_at<?", Time.current-12.hour).order(created_at: "DESC")
  }
  scope :without_images, -> {
    where("image is null")
  }

  scope :clean, -> {
    old_messages.delete_all
  }
end

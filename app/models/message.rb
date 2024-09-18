class Message < ApplicationRecord
  encrypts :content, :reply_for, :image
  belongs_to :user
  scope :recent_messages, -> {
    Message.where("created_at>=?", Time.current-12.hour).order(created_at: "DESC")
  }

  scope :unclear, -> (last_clear_at){
    if last_clear_at.present?
      where("created_at>=?", last_clear_at)
    end
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

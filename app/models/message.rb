class Message < ApplicationRecord
  encrypts :content, :reply_for, :image
  belongs_to :user
  belongs_to :recipient, class_name: 'User', optional: true
  
  scope :recent_messages, -> {
    where("created_at>=?", Time.current-24.hour).order(created_at: "DESC")
  }

  scope :unclear, -> (last_clear_at){
    if last_clear_at.present?
      where("created_at>=?", last_clear_at)
    end
  }

  scope :old_messages, -> {
    where("created_at<?", Time.current-24.hour).order(created_at: "DESC")
  }
  scope :without_images, -> {
    where("image is null")
  }

  scope :clean, -> {
    old_messages.delete_all
  }

  # Scope to get conversation between two users
  scope :conversation_between, -> (user1_id, user2_id) {
    where(
      "(user_id = ? AND recipient_id = ?) OR (user_id = ? AND recipient_id = ?)",
      user1_id, user2_id, user2_id, user1_id
    )
  }
  
  # Scope to get unseen messages by admin
  scope :unseen_by_admin, -> {
    where(seen_by_admin_at: nil)
  }
  
  # Scope to get messages from a specific user to admin
  scope :from_user_to_admin, -> (user_id, admin_id) {
    where(user_id: user_id, recipient_id: admin_id)
  }
end

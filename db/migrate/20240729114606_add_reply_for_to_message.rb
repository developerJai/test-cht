class AddReplyForToMessage < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :reply_for, :text
  end
end

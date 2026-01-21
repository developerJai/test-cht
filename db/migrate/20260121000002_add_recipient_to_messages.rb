class AddRecipientToMessages < ActiveRecord::Migration[7.1]
  def change
    add_reference :messages, :recipient, foreign_key: { to_table: :users }, null: true
    add_index :messages, [:user_id, :recipient_id]
    add_index :messages, [:recipient_id, :user_id]
  end
end

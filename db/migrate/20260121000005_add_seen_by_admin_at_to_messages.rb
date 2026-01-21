class AddSeenByAdminAtToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :seen_by_admin_at, :datetime
    add_index :messages, :seen_by_admin_at
    add_index :messages, [:recipient_id, :seen_by_admin_at]
  end
end

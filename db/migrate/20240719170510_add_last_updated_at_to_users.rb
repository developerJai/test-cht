class AddLastUpdatedAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :last_updated_at, :datetime
  end
end

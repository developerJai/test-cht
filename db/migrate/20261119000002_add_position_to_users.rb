class AddPositionToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :position, :integer, default: 0, null: false
    add_index :users, :position
  end
end

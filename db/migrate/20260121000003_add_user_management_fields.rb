class AddUserManagementFields < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :name, :string
    add_column :users, :enabled, :boolean, default: true
    add_index :users, :enabled
  end
end

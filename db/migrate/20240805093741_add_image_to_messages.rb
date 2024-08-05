class AddImageToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :image, :string
  end
end

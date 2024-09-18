class AddImageToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :image, :text
  end
end

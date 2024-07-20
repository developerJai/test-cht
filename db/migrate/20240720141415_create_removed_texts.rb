class CreateRemovedTexts < ActiveRecord::Migration[7.1]
  def change
    create_table :removed_texts do |t|
      t.string :content
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end

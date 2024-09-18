class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :username
      t.string :password_digest
      t.datetime :last_updated_at
      t.datetime :last_clear_at
      t.timestamps
    end

    begin
      ["abcd", "qwert"].each do |us|
        User.create(username: us, password: us)
      end
    rescue StandardError => e
    end
  end
end

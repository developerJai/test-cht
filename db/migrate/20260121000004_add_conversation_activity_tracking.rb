class AddConversationActivityTracking < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :conversation_activities, :json, default: {}
  end
end

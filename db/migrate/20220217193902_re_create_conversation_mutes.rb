class ReCreateConversationMutes < ActiveRecord::Migration[6.0]
  def change
    create_table :conversation_mutes do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id, null: false
    end

    add_index :conversation_mutes, [:account_id, :conversation_id], unique: true
  end
end

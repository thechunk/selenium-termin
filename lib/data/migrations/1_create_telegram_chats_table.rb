Sequel.extension(:migration)

Sequel.migration do
  up do
    create_table(:telegram_chats) do
      primary_key :id
      String :chat_id, unique: true, null: false
    end
  end

  down do
    drop_table(:telegram_chats)
  end
end

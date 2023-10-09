Sequel.extension(:migration)

Sequel.migration do
  up do
    create_table(:run_logs) do
      primary_key :id
      String :session_id, unique: true, null: false
      String :error, text: true
      String :page_source, text: true
      String :last_url
      File :last_screenshot
    end
  end

  down do
    drop_table(:run_logs)
  end
end

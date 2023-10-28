Sequel.extension(:migration)

Sequel.migration do
  up do
    create_table(:run_history) do
      primary_key :id
      foreign_key :run_log_id, :run_logs
      Integer :step, null: false
      String :method, null: false
    end
  end

  down do
    drop_table(:run_history)
  end
end

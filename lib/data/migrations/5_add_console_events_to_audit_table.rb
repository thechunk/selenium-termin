Sequel.extension(:migration)

Sequel.migration do
  up do
    add_column(:run_logs, :console_events, String, text: true)
  end

  down do
    drop_column(:run_logs, :console_events)
  end
end

Sequel.extension(:migration)

Sequel.migration do
  up do
    add_column(:run_logs, :start_at, DateTime)
    add_column(:run_logs, :end_at, DateTime)
    from(:run_logs).update(start_at: DateTime.now)
    from(:run_logs).update(end_at: DateTime.now)
  end

  down do
    drop_column(:run_logs, :start_at)
    drop_column(:run_logs, :end_at)
  end
end

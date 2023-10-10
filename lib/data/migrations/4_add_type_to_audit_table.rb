Sequel.extension(:migration)

Sequel.migration do
  up do
    add_column(:run_logs, :status, String)
    from(:run_logs).where(error: nil).update(status: 'fail')
    from(:run_logs).exclude(error: nil).update(status: 'error')
  end

  down do
    drop_column(:run_logs, :status)
  end
end

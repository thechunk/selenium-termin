Sequel.extension(:migration)

Sequel.migration do
  up do
    add_column(:run_logs, :keep, TrueClass, default: false)
    from(:run_logs).where(status: 'error').update(keep: true)
    from(:run_logs).where(status: 'success').update(keep: true)
  end

  down do
    drop_column(:run_logs, :keep)
  end
end

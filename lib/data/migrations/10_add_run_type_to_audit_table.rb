Sequel.extension(:migration)

Sequel.migration do
  up do
    add_column(:run_logs, :type, String)
    from(:run_logs).update(type: 'LeaExtend')
  end

  down do
    drop_column(:run_logs, :type)
  end
end

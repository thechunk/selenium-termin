Sequel.extension(:migration)

Sequel.migration do
  up do
    add_column(:run_history, :end_at, DateTime)
  end

  down do
    drop_column(:run_history, :end_at)
  end
end

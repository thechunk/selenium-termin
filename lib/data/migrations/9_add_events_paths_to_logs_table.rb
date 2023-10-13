Sequel.extension(:migration)

Sequel.migration do
  up do
    log_data_path = "#{File.expand_path(Dir.pwd)}/lib/web/public/logs"

    [:page_source, :console_events, :network_events, :driver_events]
      .each do |col|
        new_col = "#{col.to_s}_path".to_sym
        add_column(:run_logs, new_col, String)

        where = {}
        where[new_col] = nil
        exclude = {}
        exclude[col] = nil

        from(:run_logs)
          .where(where)
          .exclude(exclude)
          .each do |log|
            path = "#{log_data_path}/#{log[:session_id]}"
            rel_data_path = "logs/#{log[:session_id]}"
            file_path = "#{path}/#{col.to_s}"
            transaction do
              Dir.mkdir(path) unless Dir.exist?(path)
              File.open(file_path, 'w') { |f| f << log[col] }

              update_hash = {}
              update_hash[new_col] = "#{rel_data_path}/#{col.to_s}"
              update_hash[col] = nil

              from(:run_logs).where(id: log[:id]).update(update_hash)
            end
          end
      end
  end

  down do
    [:page_source, :console_events, :network_events, :driver_events]
      .each do |col|
        new_col = "#{col.to_s}_path".to_sym
        drop_column(:run_logs, new_col)
      end
  end
end

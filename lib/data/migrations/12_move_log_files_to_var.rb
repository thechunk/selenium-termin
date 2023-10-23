require 'fileutils'
Sequel.extension(:migration)

Sequel.migration do
  up do
    log_data_path = "#{File.expand_path(Dir.pwd)}/var/log_data"

    [:last_screenshot, :page_source, :console_events, :network_events, :driver_events]
      .each do |col|
        path_col = "#{col.to_s}_path".to_sym
        filename = col.to_s
        filename = "#{filename}.png" if col == :last_screenshot

        exclude = {}
        exclude[path_col] = nil
        update = {}
        update[path_col] = Sequel.join([log_data_path, :session_id, filename], '/')

        from(:run_logs).exclude(exclude).update(update)
      end

    FileUtils.mv(Dir.glob("#{File.expand_path(Dir.pwd)}/web/public/logs/*"), log_data_path)
  end

  down do
    log_data_path = "logs"

    [:last_screenshot, :page_source, :console_events, :network_events, :driver_events]
      .each do |col|
        path_col = "#{col.to_s}_path".to_sym

        exclude = {}
        exclude[path_col] = nil
        update = {}
        update[path_col] = Sequel.join([log_data_path, :session_id, col.to_s], '/')

        from(:run_logs).exclude(exclude).update(update)
      end

    FileUtils.mkdir("#{File.expand_path(Dir.pwd)}/web/public/logs")
    FileUtils.mv(Dir.glob("#{File.expand_path(Dir.pwd)}/var/log_data/*"), "#{File.expand_path(Dir.pwd)}/web/public/logs")
  end
end

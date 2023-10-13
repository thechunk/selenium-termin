Sequel.extension(:migration)

Sequel.migration do
  up do
    add_column(:run_logs, :last_screenshot_path, String, after: :last_screenshot)

    log_data_path = "#{File.expand_path(Dir.pwd)}/lib/web/public/logs"
    from(:run_logs)
      .where(last_screenshot_path: nil)
      .exclude(last_screenshot: nil)
      .each do |log|
        path = "#{log_data_path}/#{log[:session_id]}"
        rel_data_path = "logs/#{log[:session_id]}"
        scr_path = "#{path}/last_screenshot.png"
        transaction do
          Dir.mkdir(path) unless Dir.exist?(path)
          File.open(scr_path, 'wb') { |f| f << log[:last_screenshot] }

          from(:run_logs)
            .where(id: log[:id])
            .update(
              last_screenshot_path: "#{rel_data_path}/last_screenshot.png",
              last_screenshot: nil
            )
        end
      end
  end

  down do
    drop_column(:run_logs, :last_screenshot_path)
  end
end

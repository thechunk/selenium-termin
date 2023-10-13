require 'objspace'

module Termin
  module Session
    class RunnerThread
      def initialize(logger: nil, notifier: nil, db: nil, &blk)
        @driver_connection = DriverConnection.new(logger:)
        @logger = logger
        @notifier = notifier
        @db = db
        @blk = blk

        @log_data_path = "#{File.expand_path(Dir.pwd)}/lib/web/public/logs"
      end

      def call
        vnc_url = 'http://localhost:7900/?autoconnect=1&resize=scale&password=secret'
        @logger.debug("VNC: #{vnc_url}")
        @logger.debug("log_data_path: #{@log_data_path}")

        Thread.fork do
          ['INT', 'TERM'].each do |signal|
            Signal.trap(signal) do
              @logger.warn("Terminating: #{signal}")
              @driver_connection.close
            end
          end

          loop do
            start_at = DateTime.now

            begin
              @driver_connection.connect
            rescue Exception => e
              @logger.error("Could not connect to Selenium: #{e.full_message}")
              next
            end

            run_log_id = nil
            run_log_data = {start_at:, status: 'fail'}
            
            begin
              session = @blk.call(@driver_connection)
              @driver_connection.open(session.root_url)
              session.call
              run_log_data[:status] = 'success'
            rescue RunFailError => e
            @logger.error("Runner failed: #{e.full_message}")
              run_log_data[:error] = e.full_message
              run_log_data[:status] = 'fail'
            rescue Exception => e
              @logger.error("Unexpected error: #{e.full_message}")
              run_log_data[:error] = e.full_message
              run_log_data[:status] = 'error'

            ensure
              console_events, network_events, driver_events = @driver_connection.logs.map do |entries|
                entries.join("\n") 
              end

              session_id = session.session_id
              log_data_path = "#{@log_data_path}/#{session_id}"
              rel_data_path = "logs/#{session_id}"

              Dir.mkdir(log_data_path) unless Dir.exist?(log_data_path)
              screenshot_file = @driver_connection.screenshot(path: "#{log_data_path}/last_screenshot.png")

              run_log_id = @db.schema[:run_logs].insert(run_log_data.merge(
                session_id:,
                page_source: session.page_source,
                console_events:,
                network_events:,
                driver_events:,
                last_url: session.current_url,
                last_screenshot_path: "#{rel_data_path}/last_screenshot.png",
                end_at: DateTime.now
              ))

              if run_log_data.key?(:error)
                @notifier.broadcast(text: "Runner failed unexpectedly: http://fedora0.replo:4567/run/#{run_log_id}")
              end

              @driver_connection.close
            end

            sleep 60 * 5
          end
        end
      end
    end
  end
end

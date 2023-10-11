module Termin
  module Session
    class RunnerThread
      def initialize(logger: nil, notifier: nil, db: nil, &blk)
        @driver_connection = DriverConnection.new(logger:)
        @logger = logger
        @notifier = notifier
        @db = db
        @blk = blk
      end

      def call
        vnc_url = 'http://localhost:7900/?autoconnect=1&resize=scale&password=secret'
        @logger.debug("VNC: #{vnc_url}")

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

              run_log_id = @db.schema[:run_logs].insert(run_log_data.merge(
                session_id: session.session_id,
                page_source: session.page_source,
                console_events:,
                network_events:,
                driver_events:,
                last_url: session.current_url,
                last_screenshot: Sequel.blob(@driver_connection.screenshot_blob),
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

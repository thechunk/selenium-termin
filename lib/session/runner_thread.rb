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
            begin
              @driver_connection.connect
            rescue Exception => e
              @logger.error(e.full_message)
              next
            end

            run_log_id = nil
            run_log_data = {}
            
            begin
              session = @blk.call(@driver_connection)
              run_log_data[:session_id] = session.session_id
              @driver_connection.open(session.root_url)
              session.call
            rescue Exception => e
              @logger.error("Runner failed: #{e.full_message}")
              run_log_data[:error] = e.full_message
            end

            begin
              session.screenshot do |image_path|
                blob = File.open(image_path, 'rb') { |file| file.read }
                
                run_log_data.merge!(
                  page_source: session.page_source,
                  last_url: session.current_url,
                  last_screenshot: Sequel.blob(blob)
                )
                
                @notifier.broadcast(text: 'Runner failed unexpectedly', image_path:) if run_log_data.key?(:error)
              end
              run_log_id = @db.schema[:run_logs].insert(run_log_data)
            rescue Exception => e
              @logger.error("Diagnostic capture failed: #{e.full_message}")
            end

            @driver_connection.close
            sleep 60 * 0.5
          end
        end
      end

      private

      def record_run(session)
      end
    end
  end
end

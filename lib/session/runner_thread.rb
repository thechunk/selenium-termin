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
          trap_sig

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
            rescue Exception => e
              @logger.error("Runner failed: #{e.full_message}")
              run_log_data[:error] = e.full_message
              run_log_data[:status] = 'error'
            ensure
              run_log_data = run_log_data.merge!(
                session_id: session.session_id,
                page_source: session.page_source,
                last_url: session.current_url,
                end_at: DateTime.now
              )
            end

            begin
              session.screenshot do |image_path|
                blob = File.open(image_path, 'rb') { |file| file.read }
                run_log_data[:last_screenshot] = Sequel.blob(blob)
                
                @notifier.broadcast(text: 'Runner failed unexpectedly', image_path:) if run_log_data.key?(:error)
              end
            rescue Exception => e
              @logger.error("Diagnostic capture failed: #{e.full_message}")
            ensure
              run_log_id = @db.schema[:run_logs].insert(run_log_data)
            end

            @driver_connection.close
            sleep 60 * 5
          end
        end
      end

      private

      def trap_sig
        ['INT', 'TERM'].each do |signal|
          Signal.trap(signal) do
            @logger.warn("Terminating: #{signal}")
            @driver_connection.close
          end
        end
      end
    end
  end
end

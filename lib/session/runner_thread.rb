module Termin
  module Session
    class RunnerThread
      attr_reader :session

      def initialize(logger: nil, notifier: nil, driver_connection: nil, db: nil, &blk)
        @logger = logger
        @notifier = notifier
        @session = session
        @driver_connection = driver_connection
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
              @session.quit()
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
            
            begin
              @session = @blk.call(@driver_connection)
              @driver_connection.open(@session.root_url)
              @session.call
              @driver_connection.close
              sleep 60 * 5
              next
            rescue Exception => e
              @logger.error("Runner failed: #{e.full_message}")
              run_log_id = @db.schema[:run_logs].insert(
                session_id: @session.session_id,
                error: e.full_message,
              )
            end

            begin
              @session.screenshot do |image_path|
                blob = File.open(image_path, 'rb') { |file| file.read }
                
                @db.schema[:run_logs].where(id: run_log_id).update(
                  page_source: @session.page_source,
                  last_url: @session.current_url,
                  last_screenshot: Sequel.blob(blob)
                ) unless run_log_id.nil?
                
                @notifier.broadcast(text: 'Runner failed unexpectedly', image_path:)
              end
            rescue Selenium::WebDriver::Error::ServerError => e
              @logger.error("Server went away: #{e.message}")
            rescue Exception => e
              @logger.error("Diagnostic capture failed: #{e.full_message}")
            end

            @driver_connection.close
            sleep 60 * 5
          end
        end
      end
    end
  end
end

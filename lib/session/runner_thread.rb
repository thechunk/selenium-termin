module Termin
  module Session
    class RunnerThread
      attr_reader :session

      def initialize(logger: nil, notifier: nil, session: nil, db: nil)
        raise ArgumentError if session.nil?
        raise ArgumentError unless session.kind_of?(BaseSession)

        @session = session
        @notifier = notifier
        @logger = logger
        @db = db
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
            run_log = nil
            
            begin
              @session.call
              sleep 60 * 5
              next
            rescue Exception => e
              @logger.error("Runner failed: #{e.full_message}")
              run_log = @db.schema[:run_logs].insert(
                session_id: @session.session_id,
                error: e.full_message,
              )
            end

            begin
              @session.screenshot do |image_path|
                blob = File.open(image_path, 'rb') { |file| file.read }
                
                run_log.update(
                  page_source: @session.page_source,
                  last_url: @session.current_url,
                  last_screenshot: Sequel.blob(blob)
                ) unless run_log.nil?
                
                @notifier.broadcast(text: 'Runner failed unexpectedly', image_path:)
              end
              
              @session.quit
            rescue Selenium::WebDriver::Error::ServerError => e
              @logger.error("Server went away: #{e.message}")
            rescue Exception => e
              @logger.error("Diagnostic capture failed: #{e.full_message}")
            end

            sleep 60 * 5
          end
        end
      end
    end
  end
end

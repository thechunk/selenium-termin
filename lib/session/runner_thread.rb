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
          ['INT', 'TERM'].each { |signal| Signal.trap(signal) { @session.quit() } }

          loop do
            begin
              @session.call
            rescue Exception => e
              @logger.error("Runner failed: #{e.message}")
              @session.screenshot do |image_path|
                blob = File.open(image_path, 'rb') { |file| file.read }
                @db.schema[:run_logs].insert(
                  session_id: @session.session_id,
                  error: e.full_message,
                  page_source: @session.page_source,
                  last_url: @session.current_url,
                  last_screenshot: Sequel.blob(blob)
                )
                @notifier.broadcast(text: 'Runner failed unexpectedly', image_path:)
              end
            ensure
              @session.quit()
            end
            sleep 60 * 5
          end
        end
      end
    end
  end
end

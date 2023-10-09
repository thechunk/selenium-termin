require 'selenium-webdriver'

module Termin
  module Session
    class RunnerThread
      attr_reader :session

      def initialize(logger: nil, notifier: nil, session: nil)
        raise ArgumentError if session.nil?
        raise ArgumentError unless session.kind_of?(BaseSession)

        @root_url = 'https://otv.verwalt-berlin.de/ams/TerminBuchen?lang=en&termin=1&dienstleister=327437&anliegen[]=328188'
        @session = session
        @notifier = notifier
        @logger = logger
      end

      def call
        vnc_url = 'http://localhost:7900/?autoconnect=1&resize=scale&password=secret'
        @logger.debug("VNC: #{vnc_url}")

        Thread.fork do
          begin
            @session.call
          rescue Exception => e
            @logger.error("Runner failed: #{e.message}")
            @session.screenshot do |image_path|
              @notifier.broadcast(text: 'Runner failed unexpectedly', image_path:)
            end
          ensure
            @session.quit()
          end
        end
      end
    end
  end
end

module Termin
  module Session
    class DriverConnection
      attr_reader :driver

      def initialize(logger: nil)
        @logger = logger
        @driver = nil
      end

      def connect(&blk)
        options = Selenium::WebDriver::Options.chrome
        options.args << '--disable-blink-features=AutomationControlled'
        options.add_emulation(user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.53 Safari/537.36')
        options.add_argument('--disable-popup-blocking')
        options.add_option('goog:loggingPrefs', {'browser' => 'ALL', 'performance' => 'ALL', 'driver' => 'ALL'})

        retries = 10

        for i in 0..retries
          begin
            url = 'http://grid:4444'
            @logger.debug("Connecting to Selenium driver: #{url}")
            @driver = Selenium::WebDriver.for(:remote, url:, options:)
          rescue Exception => e
            @logger.debug("Failed to connect: #{e.message}")
            @logger.debug("Retrying Selenium driver connection...")
            sleep(i)
            next
          end

          break
        end

        raise "Failed to connect" if @driver.nil?

        @logger.debug("Connected to Selenium: #{url}")

        begin
          @driver.execute_script('Object.defineProperty(navigator, "webdriver", {get: () => undefined})')
          blk.call(self)
        rescue Exception => e
          @logger.error(e.full_message)
        end

        @driver.quit
      end

      def method_missing(method_name, *args, &block)
        if @driver.respond_to?(method_name)
          @driver.send(method_name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @driver.respond_to?(method_name) || super
      end
    end
  end
end

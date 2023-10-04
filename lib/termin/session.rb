require 'selenium-webdriver'

module Termin
  module Lea
    class Session
      attr_reader :driver

      def initialize(logger: nil)
        @logger = logger

        options = Selenium::WebDriver::Options.chrome
        options.args << '--disable-blink-features=AutomationControlled'
        options.add_emulation(user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.53 Safari/537.36')
        options.add_argument('--disable-popup-blocking')

        loop do
          begin
            @driver = Selenium::WebDriver.for(:remote, url: 'http://grid:4444', options:)
          rescue
            sleep(5)
            next
          end

          break
        end
        @driver.execute_script('Object.defineProperty(navigator, "webdriver", {get: () => undefined})')
      end

      def delay_perform(root_url: nil, delay: 3, &blk)
        @driver.get(root_url) unless root_url.nil?
        @logger.debug("Navigated to: #{@driver.current_url}")
        sleep(delay)
        blk.call(@driver)
      end

      def wait_for_element(delay: 3, timeout: 90, &blk)
        sleep(delay)
        wait = Selenium::WebDriver::Wait.new(timeout:, ignore: [
          Selenium::WebDriver::Error::StaleElementReferenceError,
          Selenium::WebDriver::Error::ElementNotInteractableError,
          Selenium::WebDriver::Error::NoSuchElementError
        ])
        wait.until(&blk)
      end

      def quit
        @driver.quit
      end
    end
  end
end

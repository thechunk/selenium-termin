require 'selenium-webdriver'

module Termin
  module Session
    class BaseSession
      attr_reader :driver

      def initialize(logger: nil)
        @logger = logger
        begin
          driver = Driver.new(logger:, root_url:)
          driver.call
          @driver = driver.driver
        rescue Exception => e
          driver.driver.quit
          @logger.debug(e.message)
        end
      end

      def root_url
        raise NotImplementedError
      end

      def call
        raise NotImplementedError
      end

      def delay_perform(delay: 3, &blk)
        @logger.debug("Navigating to: #{@driver.current_url}")
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

      def screenshot(&blk)
        tmp = Tempfile.new(['', '.png'])
        path = tmp.path
        @logger.debug("Screenshot: #{path}")
        @driver.save_screenshot(tmp.path)
        tmp.close

        blk.call(path)
        tmp.unlink
      end

      def quit
        @driver.quit
      end
    end
  end
end
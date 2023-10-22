module Termin
  module Session
    class BaseSession
      ELEMENT_DELAY = 2
      ELEMENT_TIMEOUT = 120
      LOADING_TIMEOUT = 30

      attr_reader :driver

      def initialize(driver: nil)
        @logger = Util::Logger.instance
        @notifier = Telegram::Notifier.instance
        @driver = driver
      end

      def call
        raise NotImplementedError
      end

      def get(url)
        @driver.get(url)
      end

      def click(delay: ELEMENT_DELAY, **opts)
        sleep(delay) if delay > 0
        element = wait_for_element(**opts)

        element.click
      end

      def loading_wait(timeout: LOADING_TIMEOUT)
        @logger.debug("Document loading...")

        begin
          wait_for_element(timeout:, css: 'body > .loading') do |element|
            !element.displayed?
          end
        rescue Selenium::WebDriver::Error::NoSuchElementError
          @logger.debug("No loader found in DOM")
        end
      end

      def delay_perform(delay: ELEMENT_DELAY, &blk)
        @logger.debug("Navigating to: #{@driver.current_url}")
        sleep(delay)
        blk.call(@driver)
      end

      def wait_for_element(delay: ELEMENT_DELAY, timeout: ELEMENT_TIMEOUT, **opts, &blk)
        @logger.debug("Navigated to: #{@driver.current_url}")

        sleep(delay)
        @logger.debug("Waiting #{timeout}s for element: #{opts}")

        wait = Selenium::WebDriver::Wait.new(timeout:, ignore: [
          Selenium::WebDriver::Error::StaleElementReferenceError,
          Selenium::WebDriver::Error::ElementNotInteractableError,
          Selenium::WebDriver::Error::NoSuchElementError
        ])

        element = nil
        wait.until do
          element = @driver.find_element(opts)
          if block_given?
            next blk.call(element)
          else
            next element.displayed?
          end
        end

        element
      end
    end
  end
end

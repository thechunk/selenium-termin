require 'net/http'
require 'selenium-webdriver'

module Termin
  module Lea
    class Session
      attr_reader :driver

      def initialize
        @options = Selenium::WebDriver::Options.chrome
        @options.args << '--disable-blink-features=AutomationControlled'
        @options.add_emulation(user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.53 Safari/537.36')

        @driver = Selenium::WebDriver.for :remote, url: 'http://grid:4444', options: @options
        @driver.execute_script('Object.defineProperty(navigator, "webdriver", {get: () => undefined})')
      end

      def delay_perform(root_url: nil, delay: 3, &blk)
        @driver.get(root_url) unless root_url.nil?
        puts @driver.current_url
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

    class Form
      Field = Struct.new(:type, :id, :name, :css, :value) do
        def element(driver)
          return driver.find_element(id:) if id
          return driver.find_element(name:) if name
          return driver.find_element(css:) if css
        end

        def select_value(driver)
          case type
          when :select
            select = Selenium::WebDriver::Support::Select.new(self.element(driver))
            select.select_by(:text, value)
          when :radio
            self.element(driver).click
          when :label
            self.element(driver).click
          end
        end
      end

      def initialize(session, fields)
        @session = session

        @fields = fields.map { |field| Field.new(*field.values_at(*Field.members)) }
      end

      def populate
        @fields.each do |field|
          @session.wait_for_element { field.element(@session.driver).displayed? }
          field.select_value(@session.driver)
        end
      end
    end
  end
end

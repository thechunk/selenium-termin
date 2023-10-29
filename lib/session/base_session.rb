module Termin
  module Session
    class BaseSession
      ELEMENT_DELAY = 2
      ELEMENT_TIMEOUT = 120
      LOADING_TIMEOUT = 30

      attr_reader :driver, :history

      def initialize(driver: nil, run_log_id: nil)
        @logger = Util::Logger.instance
        @notifier = Telegram::Notifier.instance
        @db = Data::Connection.instance
        @driver = driver
        @run_log_id = run_log_id

        @history = []
      end

      def steps
        raise NotImplementedError
      end

      def call
        steps.each do |method_name|
          step(method_name)
        end
      end

      def step(method_name, *args, &block)
        raise NoMethodError, "undefined method `#{method_name}' for #{self}:Class" unless self.respond_to?(method_name)

        history_id = @db.schema[:run_history].insert(
          run_log_id: @run_log_id,
          step: @history.length,
          method: method_name.to_s,
          start_at: DateTime.now
        )
        @history << [method_name, args]

        begin
          self.send(method_name, *args, &block)
        rescue Exception => e
          raise
        ensure
          @db.schema[:run_history].where(id: history_id).update(end_at: DateTime.now)
        end
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
        rescue Selenium::WebDriver::Error::NoSuchElementError, Selenium::WebDriver::Error::UnknownError => e
          @logger.error("No loader found in DOM: #{e.full_message}")
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

      def wait_user_input
        @notifier.broadcast(text: "Waiting for user input: #{ENV['VNC_URL']}")
        @notifier.prompt

        attempts = 3 * 60
        until @notifier.prompt_waiting == false || attempts <= 0 do
          if attempts % 60 == 0
            @logger.debug("Waiting for user input...")
          end
          attempts = attempts - 1
          sleep 1
        end
      end
    end
  end
end

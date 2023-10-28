module Termin
  module Session
    class BaseLeaSession < BaseSession
      def initialize(driver: nil, run_log_id: nil)
        super(driver:, run_log_id:)
      end

      def form
        raise NotImplementedError
      end

      def steps
        [
          :load_root,
          :begin_wizard,
          :accept_terms,
          :next_stage,
          :fill_form,
          :next_stage,
          :validate_error_message,
          :select_calendar_date,
          :select_time,
          :bypass_captcha,
          :next_stage,
          :wait_for_first_name
        ]
      end

      def call
        steps.each do |method_name|
          step(method_name)
        end
      end

      def load_root
        get('https://otv.verwalt-berlin.de/ams/TerminBuchen?lang=en&termin=1&dienstleister=327437&anliegen[]=328188')
      end

      def begin_wizard
        loading_wait
        click(css: '.slide-content .link > a')
      end

      def accept_terms
        loading_wait
        click(name: 'gelesen')
      end

      def next_stage
        loading_wait
        click(id: 'applicationForm:managedForm:proceed')
      end

      def fill_form
        loading_wait
        form.populate
      end

      def validate_error_message
        loading_wait
        begin
          messages_box = wait_for_element(id: 'messagesBox') do |element|
            element.displayed? && element.text.length > 0
          end
          no_dates_error = 'There are currently no dates available for the selected service! Please try again later.'
          no_dates = messages_box.text == no_dates_error

          raise RunFailError.new(no_dates_error) if no_dates
        rescue Selenium::WebDriver::Error::TimeoutError => e
          @logger.error(e.full_message)
          @logger.info("messages_box: #{messages_box}")
          @logger.info("no_dates: #{no_dates}")
        end
      end

      def select_calendar_date
        calendar_element = wait_for_element(id: 'xi-fs-2')
        day_elements = calendar_element.find_elements(css: 'td[data-handler="selectDay"]')

        available_days = []
        day_elements.each do |day_element|
          day = day_element.text
          month = day_element.attribute('data-month')
          year = day_element.attribute('data-year')

          available_days << "#{day}.#{month}.#{year}"
        end

        @notifier.broadcast(text: "Appointments available:\n#{available_days.join("\n* ")}")

        last_day_element = day_elements.last
        @logger.debug("Selecting last available opening: #{last_day_element}")

        last_day_element.click
      end

      def select_time
        loading_wait
        time_select_element = wait_for_element(id: 'xi-sel-3') do |element|
          element.displayed? && element.find_elements(css: 'option[name]').empty?
        end
        time_option_elements = time_select_element.find_elements(tag_name: 'option')
        time_options = time_option_elements.map(&:text).join("\n* ")

        @notifier.broadcast(text: "Times available for last opening:\n#{time_options}")

        first_time_element = time_option_elements.select do |element|
          element.text.split(':').first.to_i > 8
        end.first

        @logger.debug("Selecting first available time: #{first_time_element}")

        time_select = Selenium::WebDriver::Support::Select.new(time_select_element)
        time_select.select_by(:text, first_time_element.text)
      end

      def wait_for_first_name
        loading_wait
        wait_for_element(name: 'antragsteller_vname')
      end

      def bypass_captcha
        @logger.debug('Trying captcha...')

        captcha_iframe = @driver.find_element(css: 'iframe[title="reCAPTCHA"]')
        @driver.switch_to.frame(captcha_iframe)
        captcha_checkbox_rect = @driver
          .find_element(css: '#rc-anchor-container .recaptcha-checkbox-border')
          .rect

        @logger.debug("Captcha checkbox found at: #{captcha_checkbox_rect}")

        @driver.action
          .move_to_location(captcha_checkbox_rect.x + 1, captcha_checkbox_rect.y + 1)
          .click
          .perform

        @driver.switch_to.default_content
      end
    end
  end
end

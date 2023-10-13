module Termin
  module Session
    class LeaExtend < BaseSession
      def initialize(logger: nil, notifier: nil, driver: nil)
        super(logger:, driver:)

        @notifier = notifier
        @logger = logger
      end

      def root_url
        'https://otv.verwalt-berlin.de/ams/TerminBuchen?lang=en&termin=1&dienstleister=327437&anliegen[]=328188'
      end

      def call
        delay_perform do |driver|
          book_link = driver.find_element(css: '.slide-content .link > a')
          book_link.click
        end

        agree_checkbox = nil
        wait_for_element do
          agree_checkbox = driver.find_element(name: 'gelesen')
          agree_checkbox.displayed?
        end
        agree_checkbox.click

        delay_perform do |driver|
          next_button = driver.find_element(id: 'applicationForm:managedForm:proceed')
          next_button.click
        end

        form = Form.new(self, [
          { type: :select, name: 'sel_staat', value: 'China' },
          { type: :select, name: 'personenAnzahl_normal', value: 'one person' },
          { type: :select, name: 'lebnBrMitFmly', value: 'yes' },
          { type: :select, name: 'fmlyMemNationality', value: 'Canada' },
          { type: :label, css: '[for="SERVICEWAHL_EN3479-0-2"]' },
          { type: :label, css: '[for="SERVICEWAHL_EN_479-0-2-4"]' },
          { type: :label, css: '[for="SERVICEWAHL_EN479-0-2-4-305289"]' }
        ]).populate

        delay_perform do |driver|
          next_button = driver.find_element(id: 'applicationForm:managedForm:proceed')
          next_button.click
        end

        delay_perform do |driver|
          no_dates = false
          messages_box = nil

          wait_for_element do
            messages_box = driver.find_element(id: 'messagesBox')
            messages_box.displayed? && messages_box.text.length > 0
          end
          no_dates_error = 'There are currently no dates available for the selected service! Please try again later.'
          no_dates = messages_box.text == no_dates_error

          date_selection_text = 'Date selection'
          date_selection_active = driver.find_element(class: 'antcl_active').text == date_selection_text

          raise RunFailError.new(no_dates_error) if no_dates

          begin
            wait_for_element do
              appointment_selection_fieldset = driver.find_element(id: 'xi-fs-2')
              appointment_selection_fieldset.displayed?
            end

            @notifier.broadcast(text: 'Appointments available')
          rescue Selenium::WebDriver::Error::TimeoutError => e
            @logger.info("messages_box: #{messages_box}")
            @logger.info("no_dates: #{no_dates}")
            @logger.info("date_selection_active: #{date_selection_active}")

            raise
          end
        end
      end
    end
  end
end

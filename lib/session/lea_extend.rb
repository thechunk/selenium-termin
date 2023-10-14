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
        loading_wait
        click(css: '.slide-content .link > a')

        loading_wait
        click(name: 'gelesen')

        loading_wait
        click(id: 'applicationForm:managedForm:proceed')

        loading_wait
        form = Form.new(self, [
          { name: 'sel_staat', value: 'China' },
          { name: 'personenAnzahl_normal', value: 'one person' },
          { name: 'lebnBrMitFmly', value: 'yes' },
          { name: 'fmlyMemNationality', value: 'Canada' },
          { css: '[for="SERVICEWAHL_EN3479-0-2"]' },
          { css: '[for="SERVICEWAHL_EN_479-0-2-4"]' },
          { css: '[for="SERVICEWAHL_EN479-0-2-4-305289"]' }
        ]).populate

        click(id: 'applicationForm:managedForm:proceed')

        delay_perform do |driver|
          no_dates = false
          messages_box = nil

          messages_box = wait_for_element(id: 'messagesBox') do |element|
            element.displayed? && element.text.length > 0
          end
          no_dates_error = 'There are currently no dates available for the selected service! Please try again later.'
          no_dates = messages_box.text == no_dates_error

          date_selection_text = 'Date selection'
          date_selection_active = driver.find_element(class: 'antcl_active').text == date_selection_text

          raise RunFailError.new(no_dates_error) if no_dates

          begin
            wait_for_element(id: 'xi-fs-2')

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

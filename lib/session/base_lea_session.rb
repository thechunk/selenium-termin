module Termin
  module Session
    class BaseLeaSession < BaseSession
      def initialize(logger: nil, notifier: nil, driver: nil)
        super(logger:, driver:)

        @notifier = notifier
        @logger = logger
      end

      def root_url
        'https://otv.verwalt-berlin.de/ams/TerminBuchen?lang=en&termin=1&dienstleister=327437&anliegen[]=328188'
      end

      def form
        raise NotImplementedError
      end

      def call
        loading_wait
        click(css: '.slide-content .link > a')

        loading_wait
        click(name: 'gelesen')

        loading_wait
        click(id: 'applicationForm:managedForm:proceed')

        loading_wait
        form.populate

        loading_wait
        click(id: 'applicationForm:managedForm:proceed')

        loading_wait
        begin
          messages_box = wait_for_element(id: 'messagesBox') do |element|
            element.displayed? && element.text.length > 0
          end
          no_dates_error = 'There are currently no dates available for the selected service! Please try again later.'
          no_dates = messages_box.text == no_dates_error

          raise RunFailError.new(no_dates_error) if no_dates

          wait_for_element(id: 'xi-fs-2')

          @notifier.broadcast(text: 'Appointments available')
        rescue Selenium::WebDriver::Error::TimeoutError => e
          @logger.info("messages_box: #{messages_box}")
          @logger.info("no_dates: #{no_dates}")

          raise
        end
      end
    end
  end
end

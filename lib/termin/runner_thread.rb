require 'selenium-webdriver'

module Termin
  module Lea
    class RunnerThread
      attr_reader :session

      def initialize(logger: nil, notifier: nil)
        @root_url = 'https://otv.verwalt-berlin.de/ams/TerminBuchen?lang=en&termin=1&dienstleister=327437&anliegen[]=328188'
        @session = Session.new(logger:)
        @notifier = notifier
        @logger = logger
      end

      def call
        vnc_url = 'http://localhost:7900/?autoconnect=1&resize=scale&password=secret'
        @logger.debug("VNC: #{vnc_url}")

        Thread.fork do
          begin
            @session.delay_perform(root_url: @root_url) do |driver|
              book_link = driver.find_element(css: '.slide-content .link > a')
              book_link.click
            end

            agree_checkbox = nil
            @session.wait_for_element do
              agree_checkbox = @session.driver.find_element(name: 'gelesen')
              agree_checkbox.displayed?
            end
            agree_checkbox.click

            @session.delay_perform do |driver|
              next_button = driver.find_element(id: 'applicationForm:managedForm:proceed')
              next_button.click
            end

            form = Form.new(@session, [
              { type: :select, name: 'sel_staat', value: 'China' },
              { type: :select, name: 'personenAnzahl_normal', value: 'one person' },
              { type: :select, name: 'lebnBrMitFmly', value: 'yes' },
              { type: :select, name: 'fmlyMemNationality', value: 'Canada' },
              { type: :label, css: '[for="SERVICEWAHL_EN3479-0-2"]' },
              { type: :label, css: '[for="SERVICEWAHL_EN_479-0-2-4"]' },
              { type: :label, css: '[for="SERVICEWAHL_EN479-0-2-4-328188"]' }
            ]).populate

            @session.delay_perform do |driver|
              next_button = driver.find_element(id: 'applicationForm:managedForm:proceed')
              next_button.click
            end

            @session.delay_perform do |driver|
              no_dates = false
              messages_box = nil

              @session.wait_for_element do
                messages_box = @session.driver.find_element(id: 'messagesBox')
                messages_box.displayed? && messages_box.text.length > 0
              end
              no_dates_error = 'There are currently no dates available for the selected service! Please try again later.'
              no_dates = messages_box.text == no_dates_error

              date_selection_text = 'Date selection'
              date_selection_active = driver.find_element(class: 'antcl_active').text == date_selection_text

              if !no_dates && date_selection_active
                @notifier.broadcast(text: 'Appointments available')
              else
                @logger.info("no_dates: #{no_dates}")
                @logger.info("date_selection_active: #{date_selection_active}")
              end
            end

            @session.quit()
          rescue Exception => e
            @logger.error("Runner failed: #{e.message}")
            @session.screenshot do |image_path|
              @notifier.broadcast(text: 'Runner failed unexpectedly', image_path:)
            end
            @session.quit()
          end
        end
      end
    end
  end
end

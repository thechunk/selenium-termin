require 'net/http'
require 'selenium-webdriver'

module Termin
  module Lea
    class RunnerThread
      def initialize(bot: nil, chat_ids: [])
        @root_url = 'https://otv.verwalt-berlin.de/ams/TerminBuchen?lang=en&termin=1&dienstleister=327437&anliegen[]=328188'
        @session = Session.new
        @bot = bot
        @chat_ids = chat_ids
        puts 'http://localhost:7900/?autoconnect=1&resize=scale&password=secret'
      end

      def call
        Thread.fork do
          @bot.api.send_message(chat_id: @chat_ids[0], text: 'hi') unless @chat_ids.empty?

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
              messages_box.displayed?
            end
            no_dates_error = 'There are currently no dates available for the selected service! Please try again later.'
            no_dates = messages_box.text == no_dates_error
            puts 'no dates' if no_dates

            date_selection_text = 'Date selection'
            date_selection_active = driver.find_element(class: 'antcl_active').text == date_selection_text
            puts 'on date_selection' if date_selection_active

            if !no_dates && date_selection_active
              @bot.api.send_message(chat_id: @chat_ids[0], text: 'success') unless @chat_ids.empty?
            else
              @bot.api.send_message(chat_id: @chat_ids[0], text: 'fail') unless @chat_ids.empty?
            end
          end

          @session.quit
        end
      end
    end
  end
end

module Termin
  module Session
    class BaseBurgerSession < BaseSession
      def service_id
        raise NotImplementedError
      end

      def provider_ids
        [
          122217,
          122227,
          122231,
          122238,
          122243,
          122260,
          122262,
          122280,
          122284,
          122285,
          122286,
          122297,
          122304,
          122311,
          122257
        ]
      end

      def steps
        [
          :load_root,
          :validate_error_message,
          [:wait_user_input, [{class: 'calendar-table'}]]
        ]
      end

      def load_root
        get("https://service.berlin.de/terminvereinbarung/termin/restart/?providerList=#{provider_ids.join('%2C')}&requestList=#{service_id}&source=dldb")
      end

      def validate_error_message
        header = wait_for_element(css: 'h1.title')
        no_dates_error = 'Leider sind aktuell keine Termine für ihre Auswahl verfügbar.'
        taken_url = 'https://service.berlin.de/terminvereinbarung/termin/taken/'

        raise RunFailError.new(taken_url) if @driver.current_url == taken_url
        raise RunFailError.new(no_dates_error) if header.text == no_dates_error
      end
    end
  end
end

require 'pry'
require 'net/http'
require 'selenium-webdriver'

puts 'http://localhost:7900/?autoconnect=1&resize=scale&password=secret'

module LeaTermin
  class Session
    attr_reader :driver

    def initialize
      @options = Selenium::WebDriver::Options.chrome
      @options.args << '--disable-blink-features=AutomationControlled'
      @options.add_emulation(user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.53 Safari/537.36')

      @driver = Selenium::WebDriver.for :remote, url: 'http://grid:4444', options: @options
      @driver.execute_script('Object.defineProperty(navigator, "webdriver", {get: () => undefined})')
      @driver.manage.timeouts.implicit_wait = 10
    end

    def delay_perform(root_url: nil, delay: 3, &blk)
      @driver.get(root_url) unless root_url.nil?
      puts @driver.current_url
      sleep(delay)
      blk.call(@driver)
    end

    def wait_for_element(element, delay: 3, &blk)
      sleep(delay)
      wait = Selenium::WebDriver::Wait.new(timeout: 30, ignore: [
        Selenium::WebDriver::Error::StaleElementReferenceError,
        Selenium::WebDriver::Error::ElementNotInteractableError,
        Selenium::WebDriver::Error::NoSuchElementError
      ])
      wait.until { element.displayed? }
      blk.call(@driver)
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
        element = field.element(@session.driver)
        @session.wait_for_element(element) { |driver| field.select_value(driver) }
      end
    end
  end
end

url = 'https://otv.verwalt-berlin.de/ams/TerminBuchen?lang=en&termin=1&dienstleister=327437&anliegen[]=328188'

Net::HTTP.get(URI('http://telegram:4567/send'))

lea_termin_session = LeaTermin::Session.new
lea_termin_session.delay_perform(root_url: url) do |driver|
  book_link = driver.find_element(css: '.slide-content .link > a')
  book_link.click
end

lea_termin_session.delay_perform do |driver|
  agree_checkbox = driver.find_element(name: 'gelesen')
  agree_checkbox.click
end

lea_termin_session.delay_perform do |driver|
  next_button = driver.find_element(id: 'applicationForm:managedForm:proceed')
  next_button.click
end

form = LeaTermin::Form.new(lea_termin_session, [
  { type: :select, name: 'sel_staat', value: 'China' },
  { type: :select, name: 'personenAnzahl_normal', value: 'one person' },
  { type: :select, name: 'lebnBrMitFmly', value: 'yes' },
  { type: :select, name: 'fmlyMemNationality', value: 'Canada' },
  { type: :label, css: '[for="SERVICEWAHL_EN3479-0-2"]' },
  { type: :label, css: '[for="SERVICEWAHL_EN_479-0-2-4"]' },
  { type: :label, css: '[for="SERVICEWAHL_EN479-0-2-4-328188"]' }
]).populate

lea_termin_session.delay_perform do |driver|
  next_button = driver.find_element(id: 'applicationForm:managedForm:proceed')
  next_button.click
end

lea_termin_session.delay_perform do |driver|
  no_dates_error = 'There are currently no dates available for the selected service! Please try again later.'
  no_dates = driver.find_element(id: 'messagesBox').text == no_dates_error
  puts 'no dates' if no_dates

  date_selection_text = 'Date selection'
  date_selection_active = driver.find_element(class: 'antcl_active').text == date_selection_text
  puts 'on date_selection' if date_selection_active

  if !no_dates && date_selection_active
    Net::HTTP.get(URI('http://telegram:4567/fail'))
  else
    Net::HTTP.get(URI('http://telegram:4567/success'))
  end
end

lea_termin_session.quit

#driver.quit() if driver.current_url == 'https://otv.verwalt-berlin.de/ams/TerminBuchen/logout'

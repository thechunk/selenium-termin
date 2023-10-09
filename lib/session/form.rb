require 'selenium-webdriver'

module Termin
  module Session
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

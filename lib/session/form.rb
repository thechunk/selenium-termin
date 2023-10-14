module Termin
  module Session
    class Form
      def initialize(session, fields)
        @session = session
        @fields = fields
      end

      def populate
        @fields.each do |field|
          @session.loading_wait

          opts = field.reject { |k| k == :value }
          element = @session.wait_for_element(**opts)

          case element.tag_name.to_sym
          when :select
            select = Selenium::WebDriver::Support::Select.new(element)
            select.select_by(:text, field[:value])
          when :radio
          when :label
            element.click
          end
        end
      end
    end
  end
end

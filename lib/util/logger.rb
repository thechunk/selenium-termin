module Termin
  module Util
    class Logger < ::Logger
      include Singleton

      def initialize
        super(STDOUT)
        self.level = Logger::WARN
        self.level = Logger::DEBUG if ENV['APP_ENV'] == 'development'
      end
    end
  end
end

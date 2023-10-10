module Termin
  module Data
    class Connection
      attr_reader :schema

      def initialize(logger:, path:, debug: false)
        @logger = logger unless logger.nil?
        @schema = Sequel.sqlite(path)
        @schema.loggers << logger if debug
      end

      def migrate
        migrations_path = File.expand_path("#{File.dirname(__FILE__)}/migrations")
        @logger.debug("Running migrations from: #{migrations_path}")
        Sequel::Migrator.run(@schema, migrations_path)
      end
    end
  end
end

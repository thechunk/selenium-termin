Sequel.extension(:migration)

module Termin
  module Data
    class Connection
      include Singleton
      attr_accessor :path, :debug
      attr_reader :schema

      def initialize
        @logger = Util::Logger.instance
      end

      def connect
        @schema = Sequel.sqlite('./data.db' || @path)
        @schema.loggers << @logger if @debug
      end

      def migrate
        migrations_path = File.expand_path("#{File.dirname(__FILE__)}/migrations")
        @logger.debug("Running migrations from: #{migrations_path}")
        Sequel::Migrator.run(@schema, migrations_path)
      end
    end
  end
end

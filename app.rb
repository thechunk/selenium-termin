$stdout.sync = true # https://stackoverflow.com/a/42344140

require 'bundler'
Bundler.setup(:default, ENV['APP_ENV'])
Bundler.require(:default, ENV['APP_ENV'])
require 'logger'
Dir.glob('lib/**/*.rb').each { |f| require_relative f }

module Termin
  module Main
    class << self
      def run
        logger = Logger.new(STDOUT)
        logger.level = Logger::WARN
        logger.level = Logger::DEBUG if ENV['APP_ENV'] == 'development'

        db = Data::Connection.new(logger:, path: './data.db')
        db.migrate

        token = File.read('./telegramtoken').chomp
        bot = ::Telegram::Bot::Client.new(token)

        notifier = Telegram::Notifier.new(logger:, bot:, db:)

        telegram_instance = Telegram::ListenerThread.new(logger:, bot:, notifier:)
        telegram_thread = telegram_instance.call

        runner = Session::RunnerThread.new(logger:, notifier:, db:) do |driver_connection|
          Session::LeaExtend.new(logger:, notifier:, driver: driver_connection.driver)
        end
        runner_thread = runner.call
        logger.debug(runner_thread)

        web_instance = Web::Server.new(db:)

        runner_thread.join
      end
    end
  end
end

Termin::Main.run

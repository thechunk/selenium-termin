$stdout.sync = true # https://stackoverflow.com/a/42344140
require 'logger'
Dir.glob('lib/**/*.rb').each { |f| require_relative f }

module Termin
  module Main
    class << self
      def run
        logger = Logger.new(STDOUT)
        logger.level = Logger::DEBUG

        db = Data::Connection.new(logger:, path: './data.db')
        db.migrate

        token = File.read('./telegramtoken').chomp
        bot = ::Telegram::Bot::Client.new(token)

        notifier = Telegram::Notifier.new(logger:, bot:, db:)

        telegram_instance = Telegram::ListenerThread.new(logger:, bot:, notifier:)
        telegram_thread = telegram_instance.call

        loop do
          lea_runner_instance = Termin::Lea::RunnerThread.new(logger:, notifier:)
          lea_runner_thread = lea_runner_instance.call
          logger.debug(lea_runner_thread)
          sleep 60 * 5
        end
      end
    end
  end
end

Termin::Main.run

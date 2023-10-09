$stdout.sync = true # https://stackoverflow.com/a/42344140

require 'bundler'
Bundler.setup(:default, ENV['RUBY_ENV'])
Bundler.require(:default, ENV['RUBY_ENV'])
require 'telegram/bot'
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

        session = Session::LeaExtend.new(logger:, notifier:)
        runner = Session::RunnerThread.new(logger:, notifier:, session:, db:)
        runner_thread = runner.call
        logger.debug(runner_thread)

        runner_thread.join
      end
    end
  end
end

Termin::Main.run

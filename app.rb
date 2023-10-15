$stdout.sync = true # https://stackoverflow.com/a/42344140

require 'bundler'
Bundler.setup(:default, ENV['APP_ENV'])
Bundler.require(:default, ENV['APP_ENV'])
require 'zeitwerk'
require 'logger'

module Termin; end
loader = Zeitwerk::Loader.new
loader.push_dir('lib', namespace: Termin)
loader.setup

module Termin
  module Main
    class << self
      def run
        logger = Util::Logger.instance

        db = Data::Connection.instance
        db.path = './data.db'
        db.connect
        db.migrate

        token = File.read('./telegramtoken').chomp
        bot = ::Telegram::Bot::Client.new(token)

        notifier = Telegram::Notifier.instance
        notifier.bot = bot

        telegram_listener = Telegram::ListenerThread.instance
        telegram_listener.bot = bot
        telegram_listener.call

        session_runner_thread = Session::RunnerThread.new.call
        web_instance = Web::Server.new(db:)

        session_runner_thread.join
      end
    end
  end
end

Termin::Main.run

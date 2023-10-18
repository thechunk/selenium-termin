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

logger = Termin::Util::Logger.instance

db = Termin::Data::Connection.instance
db.connect
db.migrate

token = File.read('./telegramtoken').chomp
bot = ::Telegram::Bot::Client.new(token)

notifier = Termin::Telegram::Notifier.instance
notifier.bot = bot

telegram_listener = Termin::Telegram::ListenerThread.new(bot:)
session_runner = Termin::Session::RunnerThread.new
telegram_listener_thread = telegram_listener.call
session_runner_thread = session_runner.call

at_exit do
  puts 'Terminating...'
  session_runner.destroy
end

session_runner_thread.join

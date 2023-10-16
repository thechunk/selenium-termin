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

db = Termin::Data::Connection.instance
db.path = './data.db'
db.connect
db.migrate

token = File.read('./telegramtoken').chomp
bot = ::Telegram::Bot::Client.new(token)

notifier = Termin::Telegram::Notifier.instance
notifier.bot = bot

telegram_listener = Termin::Telegram::ListenerThread.new(bot:)
telegram_listener_thread = telegram_listener.call

telegram_listener_thread.join
require './bootstrap.rb'

logger = Termin::Util::Logger.instance

db = Termin::Data::Connection.instance
db.connect
db.migrate

token = File.read(ENV['TELEGRAM_TOKEN_FILE']).chomp
bot = ::Telegram::Bot::Client.new(token)

notifier = Termin::Telegram::Notifier.instance
notifier.bot = bot

telegram_listener = Termin::Telegram::ListenerThread.new(bot:)
session_runner = Termin::Runner::RunnerThread.new
telegram_listener_thread = telegram_listener.call
session_runner_thread = session_runner.call

at_exit do
  puts 'Terminating...'
  session_runner.destroy
end

session_runner_thread.join

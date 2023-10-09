$stdout.sync = true # https://stackoverflow.com/a/42344140
require 'logger'
Dir.glob('lib/**/*.rb').each { |f| require_relative f }

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

token = File.read('./telegramtoken').chomp
bot = ::Telegram::Bot::Client.new(token)

telegram_instance = Termin::Telegram::ListenerThread.new(logger:, bot:)
telegram_thread = telegram_instance.call

notifier = Termin::Util::Notifier.new(logger:, bot:, chat_ids: telegram_instance.chat_ids)

loop do
  lea_runner_instance = Termin::Lea::RunnerThread.new(logger:, notifier:)
  lea_runner_thread = lea_runner_instance.call
  logger.debug(lea_runner_thread)
  sleep 60 * 5
end

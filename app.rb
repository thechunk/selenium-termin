require 'logger'
Dir.glob('lib/**/*.rb').each { |f| require_relative f }

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

token = File.read('./telegramtoken').chomp
bot = ::Telegram::Bot::Client.new(token)

telegram_instance = Termin::Telegram::ListenerThread.new(logger:, bot:)
telegram_thread = telegram_instance.call

notifier = Termin::Util::Notifier.new(logger:, bot:)

loop do
  session = nil
  begin
    lea_runner_instance = Termin::Lea::RunnerThread.new(logger:, notifier:)
    lea_runner_thread = lea_runner_instance.call
    session = lea_runner_instance.session
  rescue Exception => e
    logger.error("Runner failed: #{e.message}")
    notifier.broadcast('Runner failed unexpectedly')
    session.driver.quit()
  end
  logger.debug(lea_runner_thread)
  sleep 60 * 5
end

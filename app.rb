require './lib/termin.rb'
require './lib/telegram.rb'

telegram_instance = Termin::Telegram::ListenerThread.new
telegram_thread = telegram_instance.call
loop do
  lea_runner_thread = Termin::Lea::RunnerThread.new(bot: telegram_instance.bot, chat_ids: telegram_instance.chat_ids).call
  puts lea_runner_thread
  sleep 60 * 5
end

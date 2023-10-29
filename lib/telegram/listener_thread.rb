module Termin
  module Telegram
    class ListenerThread
      def initialize(bot:)
        @notifier = Notifier.instance
        @logger = Util::Logger.instance
        @bot = bot
      end

      def call
        Thread.fork do
          @bot.run do |bot|
            bot.listen do |message|
              case message
              when ::Telegram::Bot::Types::CallbackQuery
                if message.data == 'prompt_done'
                  if @notifier.prompt_waiting == true
                    @notifier.prompt_waiting = false
                  else
                    @notifier.broadcast(text: 'Not waiting for user input')
                  end
                end
              when Telegram::Bot::Types::Message
                if message.text == '/start'
                  @notifier.register(message.chat.id)
                end
              end
            end
          end
        end
      end
    end
  end
end

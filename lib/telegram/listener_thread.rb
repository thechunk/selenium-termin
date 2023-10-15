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
              case message.text
              when '/start'
                @notifier.register(message.chat.id)
              end
            end
          end
        end
      end
    end
  end
end

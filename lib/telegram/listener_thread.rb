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
              when '/done'
                if @notifier.prompt_waiting == true
                  @notifier.prompt_waiting = false
                else
                  @notifier.broadcast(text: 'Not waiting for user input')
                end
              end
            end
          end
        end
      end
    end
  end
end

require 'telegram/bot'

module Termin
  module Telegram
    class ListenerThread
      def initialize(logger:, bot:, notifier:)
        @notifier = notifier
        @bot = bot
        @logger = logger
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

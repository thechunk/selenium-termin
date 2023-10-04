require 'telegram/bot'

module Termin
  module Telegram
    class ListenerThread
      attr_reader :bot, :chat_ids

      def initialize(logger:, bot:)
        @chat_ids = []
        @bot = bot
        @logger = logger
      end

      def call
        Thread.fork do
          @bot.run do |bot|
            bot.listen do |message|
              case message.text
              when '/start'
                @chat_ids << message.chat.id
                @bot.api.send_message(chat_id: message.chat.id, text: 'Registered')
                @logger.info("Chat #{message.chat.id} registered")
              end
            end
          end
        end
      end
    end
  end
end

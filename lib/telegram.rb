require 'telegram/bot'

module Termin
  module Telegram
    class ListenerThread
      attr_reader :bot, :chat_ids

      def initialize
        token = File.read('./telegramtoken').chomp
        @bot = ::Telegram::Bot::Client.new(token)
        @chat_ids = []
      end

      def call
        Thread.fork do
          @bot.run do |bot|
            bot.listen do |message|
              case message.text
              when '/start'
                @chat_ids << message.chat.id
                puts message.chat.id
              end
            end
          end
        end
      end
    end
  end
end

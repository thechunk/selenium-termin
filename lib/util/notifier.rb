module Termin
  module Util
    class Notifier
      def initialize(logger:, bot:, chat_ids:)
        @chat_ids = chat_ids
        @bot = bot
        @logger = logger
      end

      def broadcast(text: '')
        return if text.empty?

        @chat_ids.each do |chat_id|
          @bot.api.send_message(chat_id: , text:)
        end

        @logger.info("Message sent to #{@chat_ids.length} chats")
      end
    end
  end
end

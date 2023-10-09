module Termin
  module Telegram
    class Notifier
      def initialize(logger:, bot:, db:)
        @logger = logger
        @bot = bot
        @db = db
      end

      def register(chat_id)
        begin
          @db.schema[:telegram_chats].insert(chat_id:)
        rescue Sequel::UniqueConstraintViolation
          @logger.debug("Chat #{chat_id} already registered")
        ensure
          @bot.api.send_message(chat_id:, text: 'Registered')
          @logger.info("Chat #{chat_id} registered")
        end
      end

      def broadcast(text: '', image_path: nil)
        return if text.empty? || image_path.nil?

        unless image_path.nil?
          expanded_image_path = File.expand_path(image_path)
          photo = Faraday::UploadIO.new(expanded_image_path, 'image/jpeg')
        end

        @chat_ids.each do |chat_id|
          @bot.api.send_message(chat_id:, text:) if image_path.nil?
          @bot.api.send_photo(chat_id:, caption: text, photo:) unless image_path.nil?
        end

        @logger.info("Message sent to #{@chat_ids.length} chats")
      end
    end
  end
end

module Termin
  module Util
    class Notifier
      def initialize(logger:, bot:, chat_ids:)
        @chat_ids = chat_ids
        @bot = bot
        @logger = logger
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

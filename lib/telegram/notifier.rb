module Termin
  module Telegram
    class Notifier
      include Singleton
      attr_accessor :bot, :prompt_waiting

      def initialize
        @logger = Util::Logger.instance
        @db = Data::Connection.instance
        @prompt_waiting = false
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

      def broadcast(text: '', links: [], image_path: nil, prompt: false)
        return if text.empty? && image_path.nil?

        chat_ids = @db.schema[:telegram_chats].all
        chat_ids.each do |chat_id|
          message_params = { chat_id: chat_id[:chat_id] }
          if prompt == true
            @prompt_waiting = true
            kb = [links.map do |link|
              ::Telegram::Bot::Types::InlineKeyboardButton.new(**link)
            end + [
              ::Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Done', callback_data: 'prompt_done'),
            ]]
            message_params[:reply_markup] = ::Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
          end

          if image_path.nil?
            message_params[:text] = text
          else
            message_params[:caption] = text
          end

          if message_params.key?(:text)
            @bot.api.send_message(**message_params)
          elsif message_params.key?(:caption)
            expanded_image_path = File.expand_path(image_path)
            begin
              @bot.api.send_photo(**message_params.merge(
                photo: Faraday::UploadIO.new(expanded_image_path, 'image/png')
              ))
            rescue ::Telegram::Bot::Exceptions::ResponseError => e
              @logger.error(e.full_message)
              @bot.api.send_document(**message_params.merge(
                document: Faraday::UploadIO.new(expanded_image_path, 'image/png')
              ))
            ensure
              File.unlink(expanded_image_path)
            end
          end
        end

        @logger.info("Message sent to #{chat_ids.length} chats")
      end
    end
  end
end

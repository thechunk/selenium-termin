module Termin
  module Telegram
    class ListenerThread
      include Singleton
      attr_accessor :bot

      def initialize
        super
        @notifier = Notifier.instance
        @logger = Util::Logger.instance
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

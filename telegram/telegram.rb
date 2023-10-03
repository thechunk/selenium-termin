require 'sinatra/base'
require 'telegram/bot'

module Telegram
  class Notifier
    def initialize
      @bot = Telegram::Bot::Client.new(token)
    end

    def send
      @bot.send_message('hi')
    end
  end
end

bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
chat_ids = []

web_thread = Thread.fork do
  Sinatra.new do
    get '/send' do
      puts chat_ids
      bot.api.send_message(chat_id: chat_ids[0], text: 'hi')
    end
  end.run!
end

bot.run do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      chat_ids << message.chat.id
      puts message.chat.id
    end
  end
end

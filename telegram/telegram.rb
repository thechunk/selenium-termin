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

token = File.read('./telegramtoken').chomp
bot = Telegram::Bot::Client.new(token)
chat_ids = []

web_thread = Thread.fork do
  Sinatra.new do
    configure do
      set :bind, '0.0.0.0'
      set :port, '4567'
    end

    get '/send' do
      puts chat_ids
      bot.api.send_message(chat_id: chat_ids[0], text: 'hi')
    end

    get '/success' do
      puts chat_ids
      bot.api.send_message(chat_id: chat_ids[0], text: 'success')
    end

    get '/fail' do
      puts chat_ids
      bot.api.send_message(chat_id: chat_ids[0], text: 'fail')
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

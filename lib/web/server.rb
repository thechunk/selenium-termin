module Termin
  module Web
    class Server < Sinatra::Base
      configure do
        set :bind, '0.0.0.0'
        set :port, 4567
      end

      get '/' do
        erb :index
      end
    end
  end
end


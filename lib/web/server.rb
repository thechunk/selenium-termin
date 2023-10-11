module Termin
  module Web
    class Server
      def initialize(db:)
        @server = Sinatra.new do
          configure do
            set :bind, '0.0.0.0'
            set :port, 4567
            set :db, db
          end

          get '/' do
            @run_logs = settings.db.schema[:run_logs].reverse_order(:id).limit(100).all
            erb :index
          end

          get '/run/:run_log_id' do
            @log = settings.db.schema[:run_logs].where(id: params['run_log_id']).first
            erb :run
          end
        end

        @server.run!
      end
    end
  end
end


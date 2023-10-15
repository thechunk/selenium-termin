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
            type = params['type']
            page = params['p'].to_i
            limit = 20

            @run_types = ObjectSpace.each_object(Class)
              .select { |k| k < Session::BaseSession }
              .map { |k| k.to_s.split('::').last }
              .reject { |k| k.to_s.start_with?('Base') }

            run_logs_query = settings.db.schema[:run_logs].reverse_order(:start_at)
            run_logs_query = run_logs_query.where(type:) if @run_types.include?(type)

            total = run_logs_query.count
            offset = page * limit

            @query_string = "?type=#{type}&p="
            @next_id = page - 1 if page > 0
            @previous_id = page + 1 if offset + limit < total
            @run_logs = run_logs_query.limit(limit).offset(offset).all

            erb :index
          end

          get '/run/:run_log_id' do
            run_log_id = params['run_log_id']
            @log = settings.db.schema[:run_logs].where(id: run_log_id).first

            @pager_root = '/run'
            @next_id = settings.db.schema[:run_logs]
              .where{id > run_log_id}
              .order(:start_at)
              .limit(1)
              .select(:id)
              .get(:id)
            @previous_id = settings.db.schema[:run_logs]
              .where{id < run_log_id}
              .reverse_order(:start_at)
              .limit(1)
              .select(:id)
              .get(:id)

            erb :run
          end
        end

        @server.run!
      end
    end
  end
end


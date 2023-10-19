module Termin
  module Web
    class Server
      def initialize(db:)
        @server = Sinatra.new do
          configure do
            set :bind, '0.0.0.0'
            set :port, 4567
            set :db, db
            set :traps, false
            set :static_cache_control, :no_cache
          end

          get '/' do
            @page = 1 unless params.key?('p')
            @page ||= params['p'].to_i

            type = params['type']
            limit = 40

            halt 400 if @page < 1

            @run_types = ObjectSpace.each_object(Class)
              .select { |k| k < Session::BaseSession }
              .map { |k| k.to_s.split('::').last }
              .reject { |k| k.to_s.start_with?('Base') }

            run_logs_query = settings.db.schema[:run_logs].reverse_order(:start_at)
            run_logs_query = run_logs_query.where(type:) if @run_types.include?(type)

            offset = (@page - 1) * limit
            @total = run_logs_query.count
            @pages = (@total / limit.to_f).ceil

            next_id = @page - 1 if @page > 1
            next_query = URI.encode_www_form(type:, p: next_id)
            @next_path = "/?#{next_query}" unless next_id.nil?

            previous_id = @page + 1 if @page < @pages
            previous_query = URI.encode_www_form(type:, p: previous_id)
            @previous_path = "/?#{previous_query}" unless previous_id.nil?

            @first_path = "/?#{URI.encode_www_form(type:, p: 1)}" unless @page == 0
            @last_path = "/?#{URI.encode_www_form(type:, p: @pages)}" unless @page == @pages

            @run_logs = run_logs_query.limit(limit).offset(offset).all

            erb :index
          end

          get '/run/:run_log_id' do
            run_log_id = params['run_log_id']
            @log = settings.db.schema[:run_logs].where(id: run_log_id).first

            next_id = settings.db.schema[:run_logs]
              .where{id > run_log_id}
              .order(:start_at)
              .limit(1)
              .select(:id)
              .get(:id)
            previous_id = settings.db.schema[:run_logs]
              .where{id < run_log_id}
              .reverse_order(:start_at)
              .limit(1)
              .select(:id)
              .get(:id)

            @next_path = "/run/#{next_id}"
            @previous_path = "/run/#{previous_id}"

            erb :run
          end
        end

        @server.run!
      end
    end
  end
end


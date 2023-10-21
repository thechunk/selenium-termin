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
            status = params['status']
            limit = 30

            halt 400 if @page < 1

            @run_types = settings.db.schema[:run_logs].distinct(:type).select_map(:type)
            @run_statuses = settings.db.schema[:run_logs].distinct(:status).select_map(:status)

            run_logs_query = settings.db.schema[:run_logs].reverse_order(:start_at)
            run_logs_query = run_logs_query.where(type:) if @run_types.include?(type)
            run_logs_query = run_logs_query.where(status:) if @run_statuses.include?(status)

            offset = (@page - 1) * limit
            @total = run_logs_query.count
            @pages = (@total / limit.to_f).ceil

            next_id = @page - 1 if @page > 1
            next_query = URI.encode_www_form(type:, status:, p: next_id)
            @next_path = "/?#{next_query}" unless next_id.nil?

            previous_id = @page + 1 if @page < @pages
            previous_query = URI.encode_www_form(type:, status:, p: previous_id)
            @previous_path = "/?#{previous_query}" unless previous_id.nil?

            @first_path = "/?#{URI.encode_www_form(type:, status:, p: 1)}" unless @page == 1
            @last_path = "/?#{URI.encode_www_form(type:, status:, p: @pages)}" unless @page == @pages

            @run_logs = run_logs_query.limit(limit).offset(offset).all

            erb :index
          end

          get '/run/:run_log_id' do
            type = params['type']
            status = params['status']
            run_log_id = params['run_log_id']

            @log = settings.db.schema[:run_logs].where(id: run_log_id).first

            next_id_query = settings.db.schema[:run_logs].where(Sequel.lit('start_at > ?', @log[:start_at]))
            previous_id_query = settings.db.schema[:run_logs].where(Sequel.lit('start_at < ?', @log[:start_at]))

            next_id_query = next_id_query.where(type:) unless type.nil? || type.empty?
            next_id_query = next_id_query.where(status:) unless status.nil? || status.empty?

            previous_id_query = previous_id_query.where(type:) unless type.nil? || type.empty?
            previous_id_query = previous_id_query.where(status:) unless status.nil? || status.empty?

            next_id = next_id_query
              .order(:start_at)
              .limit(1)
              .select(:id)
              .get(:id)
            previous_id = previous_id_query
              .reverse_order(:start_at)
              .limit(1)
              .select(:id)
              .get(:id)

            @next_path = "/run/#{next_id}" unless next_id.nil?
            @previous_path = "/run/#{previous_id}" unless previous_id.nil?

            erb :run
          end
        end

        @server.run!
      end
    end
  end
end


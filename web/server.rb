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
            @next_path = Url.index_url(query: next_query) unless next_id.nil?

            previous_id = @page + 1 if @page < @pages
            previous_query = URI.encode_www_form(type:, status:, p: previous_id)
            @previous_path = Url.index_url(query: previous_query) unless previous_id.nil?

            @first_path = Url.index_url(query: URI.encode_www_form(type:, status:, p: 1)) unless @page == 1
            @last_path = Url.index_url(query: URI.encode_www_form(type:, status:, p: @pages)) unless @page == @pages

            @run_logs = run_logs_query.limit(limit).offset(offset).all

            erb :index
          end

          get '/run/:run_log_id' do
            type = params['type']
            status = params['status']
            run_log_id = params['run_log_id']

            @log = settings.db.schema[:run_logs].where(id: run_log_id).first
            halt 404 if @log.nil?

            next_id_query = settings.db.schema[:run_logs]
              .where(Sequel.lit('start_at > ?', @log[:start_at]))
              .order(:start_at)
            previous_id_query = settings.db.schema[:run_logs]
              .where(Sequel.lit('start_at < ?', @log[:start_at]))
              .reverse_order(:start_at)

            where = {}
            [:type, :status].each do |key|
              next unless params.key?(key.to_s)
              value = params[key.to_s]
              where[key] = value unless value.nil? || value.empty?
            end

            next_id, previous_id = [next_id_query, previous_id_query].map do |query|
              query.where(where).limit(1).select(:id).get(:id)
            end

            query = URI.encode_www_form(type:, status:)
            @index_path = Url.index_url(query:)
            @next_path = Url.run_url(next_id, query:) unless next_id.nil?
            @previous_path = Url.run_url(previous_id, query:) unless previous_id.nil?

            erb :run
          end
        end

        @server.run!
      end
    end
  end
end


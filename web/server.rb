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
            @run_statuses = Session::RunType.constants
              .reject { |const| const == :STARTED }
              .map { |const| Session::RunType.const_get(const) }

            halt 400 unless type.nil? || @run_types.include?(type)

            @title = type unless type.nil? || type.empty?

            run_logs_query = settings.db.schema[:run_logs].reverse_order(:start_at)
            run_logs_query = run_logs_query.where(type:) if @run_types.include?(type)
            run_logs_query = run_logs_query.where(status:) if @run_statuses.include?(status)

            offset = (@page - 1) * limit
            @total = run_logs_query.count
            @pages = (@total / limit.to_f).ceil

            next_id = @page - 1 if @page > 1
            @next_path = Url.index_url(
              query: Url.query(type:, status:, p: next_id),
              request:
            ) unless next_id.nil?

            previous_id = @page + 1 if @page < @pages
            @previous_path = Url.index_url(
              query: Url.query(type:, status:, p: previous_id),
              request:
            ) unless previous_id.nil?

            @first_path = ''
            @first_path = Url.index_url(
              query: Url.query(type:, status:, p: 1),
              request:
            ) unless @page == 1

            @last_path = ''
            @last_path = Url.index_url(
              query: Url.query(type:, status:, p: @pages),
              request:
            ) unless @page == @pages || @total == 0

            @running_logs, @run_logs = run_logs_query.limit(limit).offset(offset).all
              .partition { |v| v[:status] == Session::RunType::STARTED }

            erb :index
          end

          get '/run/:run_log_id' do
            type = params['type']
            status = params['status']
            run_log_id = params['run_log_id']

            @log = settings.db.schema[:run_logs]
              .where(id: run_log_id)
              .exclude(status: Session::RunType::STARTED)
              .first
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
              query.where(where).exclude(status: Session::RunType::STARTED)
                .limit(1)
                .select(:id)
                .get(:id)
            end

            query = Url.query(type:, status:)
            @next_path = Url.run_url(next_id, query:, request:) unless next_id.nil?
            @previous_path = Url.run_url(previous_id, query:, request:) unless previous_id.nil?

            erb :run
          end

          get '/run/:run_log_id/:file' do
            run_log_id = params['run_log_id']
            file = params['file']

            types = {
              'last_screenshot.png' => :png,
              'page_source' => :html,
              'console_events' => :txt,
              'network_events' => :txt,
              'driver_events' => :txt
            }
            halt 404 unless types.key?(file)

            @log = settings.db.schema[:run_logs].where(id: run_log_id).first
            halt 404 if @log.nil?

            file_path = @log["#{File.basename(file, '.png')}_path".to_sym]
            halt 404 if file_path.nil?

            send_file(file_path, type: types[file], disposition: :inline)
          end
        end

        @server.run!
      end
    end
  end
end


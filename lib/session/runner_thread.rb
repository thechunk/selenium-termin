module Termin
  module Session
    class RunnerThread
      def initialize
        @logger = Util::Logger.instance
        @driver_connection = DriverConnection.new(logger: @logger)
        @notifier = Telegram::Notifier.instance
        @db = Data::Connection.instance

        @lock = Mutex.new
        @runner_thread = nil
        @threads = []

        @log_data_path = "#{File.expand_path(Dir.pwd)}/lib/web/public/logs"
      end

      def call
        vnc_url = 'http://localhost:7900/?autoconnect=1&resize=scale&password=secret'
        @logger.debug("VNC: #{vnc_url}")
        @logger.debug("log_data_path: #{@log_data_path}")

        @runner_thread = Thread.fork do
          loop do
            prune(keep_only: 200)
            cleanup_hung if @threads.empty?

            [Session::LeaExtend, Session::LeaTransfer].each do |klass|
              @threads << Thread.fork do
                @session_id = nil
                begin
                  @lock.synchronize {
                    @driver_connection.connect do |driver_connection|
                      @session_id = driver_connection.session_id
                      execute(klass, driver_connection:)
                    end
                    sleep 60
                  }
                rescue UserInterruptError => e
                  @lock.lock unless @lock.locked?
                  @logger.debug("User interrupt: #{@session_id}")
                  @db.schema[:run_logs].where(session_id: @session_id, status: 'started').update(
                    error: e.full_message,
                    status: 'interrupt',
                    end_at: DateTime.now
                  )
                end
              end
            end

            @threads.each { |t| t.join }
          end
        end
      end

      def execute(klass, driver_connection:)
        session_id = driver_connection.session_id
        run_type = klass.to_s.split('::').last
        run_log_id = @db.schema[:run_logs].insert(
          session_id:,
          start_at: DateTime.now,
          status: 'started',
          type: run_type
        )
        run_log_data = {}

        begin
          @logger.debug("Run starting: #{run_type}")
          session = klass.new(driver: driver_connection.driver)
          session.call
          run_log_data[:status] = 'success'
          run_log_data[:keep] = true
        rescue RunFailError => e
          @logger.error("Runner failed: #{e.full_message}")
          run_log_data[:error] = e.full_message
          run_log_data[:status] = 'fail'
        rescue Exception => e
          @logger.error("Unexpected error: #{e.full_message}")
          run_log_data[:error] = e.full_message
          run_log_data[:status] = 'error'
          run_log_data[:keep] = true
        ensure
          log_data.each do |key, entries|
            run_log_data["#{key}_path"] = write_log_text(session_id, key) do |f|
              f << entries.join("\n")
            end
          end

          @db.schema[:run_logs].where(id: run_log_id).update(run_log_data.merge(
            page_source_path: write_log_text(session_id, :page_source) { |f| f << driver_connection.page_source },
            last_screenshot_path: write_log_file(session_id, :last_screenshot, ext: 'png') do |log_data_path|
              driver_connection.save_screenshot("#{log_data_path}/last_screenshot.png")
            end,
            last_url: driver_connection.current_url,
            end_at: DateTime.now
          ))

          case run_log_data[:status]
          when 'error'
            @notifier.broadcast(text: "Run failed unexpectedly: http://fedora0.replo:4567/run/#{run_log_id}")
          when 'success'
            @notifier.broadcast(text: "Run successful: http://fedora0.replo:4567/run/#{run_log_id}")
          end
        end
      end

      def destroy
        @threads.each do |thread|
          if thread.alive?
            puts "Stopping thread: #{thread}"
            thread.raise(UserInterruptError.new)
          else
            puts "Killing thread: #{thread}"
            thread.exit
          end
        end

        begin
          @driver_connection.quit
        rescue Selenium::WebDriver::Error::ServerError, Selenium::WebDriver::Error::InvalidSessionIdError => e
          puts "Selenium session already ended: #{e.message}"
        end

        @runner_thread.exit
      end

      private

      def cleanup_hung
        @db.schema[:run_logs].where(status: 'started')
          .update(status: 'interrupt', end_at: DateTime.now)
      end

      def prune(keep_only: 0)
        raise ArgumentError unless keep_only.is_a?(Integer)
        raise ArgumentError unless keep_only > 0

        @logger.debug("Pruning to keep #{keep_only}")

        @db.schema.transaction do
          keep_limit = @db.schema[:run_logs]
            .count(:id) - keep_only

          return if keep_limit < 50

          to_delete = @db.schema[:run_logs]
            .where(keep: false)
            .order(:start_at)
            .limit(keep_limit)
            .all

          to_delete_ids = []

          to_delete.each do |run_log|
            public_path = "#{File.expand_path(Dir.pwd)}/lib/web/public"
            log_data_path = "#{@log_data_path}/#{run_log[:session_id]}"
            @logger.info("Deleting files in: #{log_data_path}")

            [:last_screenshot_path, :page_source_path, :console_events_path, :network_events_path, :driver_events_path].each do |file|
              next if run_log[file].nil?
              File.unlink("#{public_path}/#{run_log[file]}")
            rescue Errno::ENOENT
              @logger.debug("File not found: #{run_log[file]}")
            end

            begin
              Dir.unlink(log_data_path)
            rescue Errno::ENOENT
              @logger.debug("Dir not found: #{log_data_path}")
            end

            to_delete_ids << run_log[:id]
          end

          @db.schema[:run_logs].where(id: to_delete_ids).delete

          @logger.info("Pruning #{to_delete_ids.count} logs...")
        end
      end

      def log_data
        [:browser, :performance, :driver].map do |type|
          log_type = case type
                     when :browser then :console_events
                     when :performance then :network_events
                     when :driver then :driver_events
                     end

          [log_type, @driver_connection.logs.get(type)]
        end.to_h
      end

      def write_log_file(session_id, type, ext: '', &blk)
        log_data_path = "#{@log_data_path}/#{session_id}"
        rel_data_path = "logs/#{session_id}"
        ext = ".#{ext}" unless ext.empty?

        Dir.mkdir(log_data_path) unless Dir.exist?(log_data_path)
        blk.call(log_data_path)

        "#{rel_data_path}/#{type.to_s}#{ext}"
      end

      def write_log_text(session_id, type, ext: '', &blk)
        ext = ".#{ext}" unless ext.empty?

        write_log_file(session_id, type, ext:) { |log_data_path| File.open("#{log_data_path}/#{type.to_s}#{ext}", 'w', &blk) }
      end
    end
  end
end

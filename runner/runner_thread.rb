module Termin
  module Runner
    class RunnerThread
      def initialize
        @logger = Util::Logger.instance
        @driver_connection = Session::DriverConnection.new(logger: @logger)
        @notifier = Telegram::Notifier.instance
        @db = Data::Connection.instance

        @runner_thread = nil

        @log_data_path = "#{File.expand_path(Dir.pwd)}/var/log_data"
      end

      def call
        @logger.debug("log_data_path: #{@log_data_path}")

        @runner_thread = Thread.fork do
          loop do
            cleanup_hung

            [BurgerErlaubnisAufNeuerPass, BurgerFahrerlaubnis, LeaExtend, LeaTransfer].each do |klass|
              @session_id = nil

              @driver_connection.connect do |driver_connection|
                @session_id = driver_connection.session_id
                execute(klass, driver_connection:)
              end

              sleep 60
            end
          end
        end
      end

      def execute(klass, driver_connection:)
        session_id = driver_connection.session_id
        run_type = klass.to_s.split('::').last
        run_log_id = @db.schema[:run_logs].insert(
          session_id:,
          start_at: DateTime.now,
          status: Session::RunType::STARTED,
          type: run_type
        )
        run_log_data = {}

        begin
          @logger.debug("Run starting: #{run_type}")
          session = klass.new(driver: driver_connection.driver, run_log_id:)
          session.call
          run_log_data[:status] = Session::RunType::SUCCESS
          run_log_data[:keep] = true
        rescue Session::RunFailError => e
          @logger.error("Runner failed: #{e.full_message}")
          run_log_data[:error] = e.full_message
          run_log_data[:status] = Session::RunType::FAIL
        rescue Session::SessionKillError => e
          @logger.error("Session killed: #{e.full_message}")
          run_log_data[:error] = e.full_message
          run_log_data[:status] = Session::RunType::SESSION_KILL
        rescue Exception => e
          @logger.error("Unexpected error: #{e.full_message}")
          run_log_data[:error] = e.full_message
          run_log_data[:status] = Session::RunType::ERROR
          run_log_data[:keep] = true
        ensure
          log_data.each do |key, entries|
            run_log_data["#{key}_path"] = write_log_text(session_id, key) do |f|
              f << entries.join("\n")
            end
          end

          @logger.debug("Step history: #{session.history}")

          @db.schema[:run_logs].where(id: run_log_id).update(run_log_data.merge(
            page_source_path: write_log_text(session_id, :page_source) { |f| f << driver_connection.page_source },
            last_screenshot_path: write_log_file(session_id, :last_screenshot, ext: 'png') do |log_data_path|
              driver_connection.save_screenshot("#{log_data_path}/last_screenshot.png")
            end,
            last_url: driver_connection.current_url,
            end_at: DateTime.now
          ))

          case run_log_data[:status]
          when Session::RunType::ERROR
            @notifier.broadcast(text: "Run failed unexpectedly: #{ENV['BASE_URL']}/run/#{run_log_id}")
          when Session::RunType::SUCCESS
            @notifier.broadcast(text: "Run successful: #{ENV['BASE_URL']}/run/#{run_log_id}")
          end
        end
      end

      def destroy
        @logger.debug("User interrupt: #{@session_id}")
        @db.schema[:run_logs].where(
          session_id: @session_id,
          status: Session::RunType::STARTED
        ).update(
          status: Session::RunType::INTERRUPT,
          end_at: DateTime.now
        )

        begin
          @driver_connection.quit
        rescue Exception => e
          puts "Selenium session already ended: #{e.message}"
        end

        @runner_thread.exit
      end

      private

      def cleanup_hung
        @db.schema[:run_logs].where(status: Session::RunType::STARTED)
          .update(status: Session::RunType::INTERRUPT, end_at: DateTime.now)
      end

      def prune(keep_only: 0)
        raise ArgumentError unless keep_only.is_a?(Integer)
        raise ArgumentError unless keep_only > 0

        @logger.debug("Pruning to keep #{keep_only}")

        @db.schema.transaction do
          deletable_count = @db.schema[:run_logs]
            .where(keep: false)
            .count(:id)

          return if deletable_count < keep_only

          to_delete = @db.schema[:run_logs]
            .where(keep: false)
            .order(:start_at)
            .limit(keep_only)
            .all

          to_delete_ids = []

          to_delete.each do |run_log|
            log_data_path = "#{@log_data_path}/#{run_log[:session_id]}"
            @logger.info("Deleting files in: #{log_data_path}")

            [
              :last_screenshot_path,
              :page_source_path,
              :console_events_path,
              :network_events_path,
              :driver_events_path
            ].each do |file|
              next if run_log[file].nil? || run_log[file].empty?
              File.unlink(run_log[file])
            rescue Errno::ENOENT
              @logger.debug("File not found: #{run_log[file]}")
            rescue Errno::ENOTEMPTY
              @logger.debug("Dir not empty: #{run_log[file]}")
            end

            begin
              Dir.unlink(log_data_path)
            rescue Errno::ENOENT
              @logger.debug("Dir not found: #{log_data_path}")
            rescue Errno::ENOTEMPTY
              @logger.debug("Dir not empty: #{log_data_path}")
            end

            to_delete_ids << run_log[:id]
          end

          @db.schema[:run_history].where(run_log_id: to_delete_ids).delete
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
        ext = ".#{ext}" unless ext.empty?

        Dir.mkdir(log_data_path) unless Dir.exist?(log_data_path)
        blk.call(log_data_path)

        "#{log_data_path}/#{type.to_s}#{ext}"
      end

      def write_log_text(session_id, type, ext: '', &blk)
        ext = ".#{ext}" unless ext.empty?

        write_log_file(session_id, type, ext:) do |log_data_path|
          Zlib::GzipWriter.open("#{log_data_path}/#{type.to_s}#{ext}", &blk)
        end
      end
    end
  end
end

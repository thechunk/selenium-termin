require 'objspace'

module Termin
  module Session
    class RunnerThread
      def initialize(logger: nil, notifier: nil, db: nil, &blk)
        @driver_connection = DriverConnection.new(logger:)
        @logger = logger
        @notifier = notifier
        @db = db
        @blk = blk

        @lock = Mutex.new

        @log_data_path = "#{File.expand_path(Dir.pwd)}/lib/web/public/logs"
      end

      def call
        vnc_url = 'http://localhost:7900/?autoconnect=1&resize=scale&password=secret'
        @logger.debug("VNC: #{vnc_url}")
        @logger.debug("log_data_path: #{@log_data_path}")
        prune(keep_only: 200)

        Thread.fork do
          @threads = []

          @threads << thread do |driver_connection|
            Session::LeaExtend.new(logger: @logger, notifier: @notifier, driver: driver_connection.driver)
          end

          @threads << thread do |driver_connection|
            Session::LeaTransfer.new(logger: @logger, notifier: @notifier, driver: driver_connection.driver)
          end

          @threads.each { |t| t.join }
        end
      end

      def thread(&blk)
        Thread.fork do
          ['INT', 'TERM'].each do |signal|
            Signal.trap(signal) do
              @logger.warn("Terminating: #{signal}")
              @driver_connection.close
            end
          end

          loop do
            @logger.debug("Loop start")

            @lock.synchronize {
              @logger.debug("Lock acquired")
              start_at = DateTime.now

              begin
                @driver_connection.connect
              rescue Exception => e
                @logger.error("Could not connect to Selenium: #{e.full_message}")
                next
              end

              run_log_id = nil
              run_log_data = {start_at:, status: 'fail'}

              begin
                session = blk.call(@driver_connection)
                run_log_data[:type] = session.class.to_s.split('::').last
                @logger.debug("Run starting: #{run_log_data[:type]}")
                @driver_connection.open(session.root_url)
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
                session_id = @driver_connection.session_id

                @driver_connection.logs.each do |key, entries|
                  log_type = case key
                             when :browser then :console_events
                             when :performance then :network_events
                             when :driver then :driver_events
                             end

                  run_log_data["#{log_type}_path"] = write_log_text(session_id, log_type) { |f| f << entries.join("\n") }
                end

                run_log_id = @db.schema[:run_logs].insert(run_log_data.merge(
                  session_id:,
                  page_source_path: write_log_text(session_id, :page_source) { |f| f << @driver_connection.page_source },
                  last_screenshot_path: write_log_file(session_id, :last_screenshot, ext: 'png') do |log_data_path|
                    @driver_connection.screenshot(path: "#{log_data_path}/last_screenshot.png")
                  end,
                  last_url: @driver_connection.current_url,
                  end_at: DateTime.now
                ))

                if run_log_data.key?(:error)
                  @notifier.broadcast(text: "Runner failed unexpectedly: http://fedora0.replo:4567/run/#{run_log_id}")
                end

                @driver_connection.close
              end

            }

            sleep 60 * 3
          end
        end
      end

      private

      def prune(keep_only: 0)
        raise ArgumentError unless keep_only.is_a?(Integer)
        raise ArgumentError unless keep_only > 0

        @db.schema.transaction do
          keep_limit = @db.schema[:run_logs]
            .count(:id) - keep_only

          return if keep_limit < 1

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

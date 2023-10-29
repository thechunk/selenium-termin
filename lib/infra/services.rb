module Termin
  module Infra
    module Services
      SELENIUM_STATUS_ENDPOINT = '/status'
      Status = Struct.new(:service, :ready, :reachable, :extra)

      class << self
        def status(service)
          case service
          when :selenium
            result = Status.new(service)

            begin
              uri = URI("#{ENV['SELENIUM_URL']}/status")
              request = Net::HTTP::Get.new(uri)
              response = Net::HTTP.start(uri.hostname, uri.port) do |http|
                http.read_timeout = 1
                http.request(request)
              end
              data = JSON.parse(response.body)
              ready = data.dig('value', 'ready')

              if ready
                result = Status.new(service, ready, true)
              else
                nodes = data.dig('value', 'nodes')
                slots = nodes.first.dig('slots')
                session = slots.first.dig('session')

                result = Status.new(service, ready, true, {
                  i18n.run.session_id.title => {
                    type: :code,
                    value: session['sessionId']
                  },
                  i18n.service.selenium.vnc_cta => {
                    type: :href,
                    value: ENV['VNC_URL']
                  },
                  i18n.service.selenium.dash_cta => {
                    type: :href,
                    value: ENV['SELENIUM_URL']
                  },
                })
              end
            rescue Exception => e
              result = Status.new(service, false, false, {
                i18n.service.messages.error => {
                  type: :code,
                  value: e.message
                }
              })
            end

            result
          when :runner
            running_logs
          end
        end

        def running_logs
          running = Data::Connection.instance.schema[:run_logs]
            .where(status: Session::RunType::STARTED)
            .first

          result = Status.new(:runner)

          pid_file = "#{File.expand_path(Dir.pwd)}/var/pid/app.rb.pid"
          unless File.exist?(pid_file)
            return Status.new(:runner, false, false)
          end

          if running.nil?
            result = Status.new(:runner, true, true)
          else
            history = Data::Connection.instance.schema[:run_history]
              .where(run_log_id: running[:id])
              .reverse_order(:step)
              .first

            extra = {
              i18n.run.id.title => {
                value: running[:id]
              },
              i18n.run.session_id.title => {
                type: :code,
                value: running[:session_id]
              },
              i18n.run.start_at.title => {
                value: running[:start_at].strftime(i18n.date.short)
              },
              i18n.run.type.title => {
                value: running[:type]
              }
            }

            unless history.nil?
              extra[i18n.run_history[:method].title] = { value: history[:method] }
            end

            result = Status.new(:runner, false, true, extra)
          end

          result
        end
      end
    end
  end
end

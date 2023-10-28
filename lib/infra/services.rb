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
                http.read_timeout = 3
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

          if running.nil?
            result = Status.new(:runner, true, true)
          else
            result = Status.new(:runner, false, true, {
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
            })
          end

          result
        end
      end
    end
  end
end

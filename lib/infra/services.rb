module Termin
  module Infra
    module Services
      class << self
        def status(service)
          case service
          when :selenium
            result = nil

            begin
              raw_data = Net::HTTP.get('fedora0.replo', '/status', 4445)
              result = JSON.parse(raw_data)
            rescue
            end

            result
          end
        end
      end
    end
  end
end

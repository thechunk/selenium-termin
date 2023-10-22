module Termin
  module Web
    module Url
      class << self
        def url_for(path: '/', query: nil, request: nil)
          base_url = "#{request.scheme}://#{request.host}:#{request.port}" unless request.nil?
          base_url = ENV['BASE_URL'] if base_url.nil?

          if query.nil? || query.empty?
            "#{base_url}#{path}"
          else
            "#{base_url}#{path}?#{query}"
          end
        end

        def index_url(query:, request: nil)
          url_for(query:, request:)
        end

        def run_url(id, query:, request: nil)
          url_for(path: "/run/#{id}", query:, request:)
        end

        def query(**opts)
          URI.encode_www_form(opts.reject { |k, v| v.nil? || v.to_s.empty? })
        end
      end
    end
  end
end

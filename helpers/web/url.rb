module Termin
  module Web
    module Url
      class << self
        def url_for(path: '/', query: nil)
          if query.nil? || query.empty?
            "#{ENV['BASE_URL']}#{path}"
          else
            "#{ENV['BASE_URL']}#{path}?#{query}"
          end
        end

        def index_url(query:)
          url_for(query:)
        end

        def run_url(id, query:)
          url_for(path: "/run/#{id}", query:)
        end
      end
    end
  end
end

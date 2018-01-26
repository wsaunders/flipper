module Flipper
  module Util
    module_function

    def timestamp(now = Time.now)
      (now.to_f * 1_000).floor
    end

    VALID_SCHEMES = [
      "http".freeze,
      "https".freeze,
    ].freeze

    def url_for(url, path)
      uri = URI(url)

      unless VALID_SCHEMES.include?(uri.scheme)
        raise ArgumentError, <<-ERR
          #{url} does not have valid scheme. schema was #{uri.scheme} \
          and valid schemes are #{VALID_SCHEMES.inspect}
        ERR
      end

      path_uri = URI(path)
      uri.path += "/#{path_uri.path}".squeeze("/")
      uri.path.squeeze!("/")

      if path_uri.query
        if uri.query
          uri.query += "&#{path_uri.query}"
        else
          uri.query = path_uri.query
        end

        uri.query.squeeze!("&")
      end

      uri.to_s
    end
  end
end

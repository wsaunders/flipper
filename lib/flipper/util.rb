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

    DEFAULT_ON_ERROR = ->(exception, attempts) {}

    # Internal: Retry a block of code with backoff that has jitter.
    def with_retry(options = {})
      raise ArgumentError, "block is required" unless block_given?

      limit = options.fetch(:limit, 10)
      sleep_enabled = options.fetch(:sleep_enabled, true)
      base = options.fetch(:base, 0.5)
      max_delay = options.fetch(:max_delay, 2.0)
      on_error = options.fetch(:on_error, DEFAULT_ON_ERROR)

      attempts ||= 0
      begin
        attempts += 1
        yield
      rescue => exception
        raise if attempts >= limit
        on_error.call(exception, attempts)
        if sleep_enabled
          sleep sleep_for_attempts(attempts, base: base, max_delay: max_delay)
        end
        retry
      end
    end

    # Private: Given the number of attempts, it returns the number of seconds
    # to sleep. Should always return a Float larger than base. Should always
    # return a Float not larger than base + max.
    #
    # attempts - The number of attempts.
    # base - The starting delay between retries.
    # max_delay - The maximum to expand the delay between retries.
    #
    # Returns Float seconds to sleep.
    private def sleep_for_attempts(attempts, base: 0.5, max_delay: 2.0)
      sleep_seconds = [base * (2**(attempts - 1)), max_delay].min
      sleep_seconds *= (0.5 * (1 + rand))
      [base, sleep_seconds].max
    end
  end
end

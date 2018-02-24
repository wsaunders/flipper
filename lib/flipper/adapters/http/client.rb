require 'uri'
require 'openssl'
require 'flipper/version'

module Flipper
  module Adapters
    class Http
      class Client
        DEFAULT_HEADERS = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'User-Agent' => "Flipper HTTP Adapter v#{VERSION}",
        }.freeze

        HTTPS_SCHEME = "https".freeze

        def initialize(options = {})
          @headers = DEFAULT_HEADERS.merge(options[:headers] || {})
          @basic_auth_username = options[:basic_auth_username]
          @basic_auth_password = options[:basic_auth_password]
          @read_timeout = options[:read_timeout]
          @open_timeout = options[:open_timeout]
          @debug_output = options[:debug_output]
        end

        def get(url, headers: {})
          perform Net::HTTP::Get, url, @headers.merge(headers)
        end

        def post(url, body: nil, headers: {})
          perform Net::HTTP::Post, url, @headers.merge(headers), body: body
        end

        def delete(url, body: nil, headers: {})
          perform Net::HTTP::Delete, url, @headers.merge(headers), body: body
        end

        private

        def perform(http_method, url, headers = {}, options = {})
          uri = URI(url)
          http = build_http(uri)
          request = build_request(http_method, uri, headers, options)
          http.request(request)
        end

        def build_http(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.read_timeout = @read_timeout if @read_timeout
          http.open_timeout = @open_timeout if @open_timeout
          http.set_debug_output(@debug_output) if @debug_output

          if uri.scheme == HTTPS_SCHEME
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end

          http
        end

        def build_request(http_method, uri, headers, options)
          request_headers = {
            "FLIPPER_TIMESTAMP" => Flipper::Util.timestamp.to_s,
          }.merge(headers)
          body = options[:body]
          request = http_method.new(uri.request_uri)
          request.initialize_http_header(request_headers)
          request.body = body if body

          if @basic_auth_username && @basic_auth_password
            request.basic_auth(@basic_auth_username, @basic_auth_password)
          end

          request
        end
      end
    end
  end
end

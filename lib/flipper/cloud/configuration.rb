require 'socket'
require 'thread'
require 'flipper/adapters/http'
require 'flipper/instrumenters/noop'
require 'flipper/cloud/producer'

module Flipper
  module Cloud
    class Configuration
      # The default url should be the one, the only, the website.
      DEFAULT_URL = "https://www.featureflipper.com/adapter".freeze

      # Public: The token corresponding to an environment on featureflipper.com.
      attr_accessor :token

      # Public: The url for http adapter (default: Flipper::Cloud::DEFAULT_URL).
      #         Really should only be customized for development work. Feel free
      #         to forget you ever saw this.
      attr_reader :url

      # Public: net/http read timeout for all http requests (default: 5).
      attr_accessor :read_timeout

      # Public: net/http open timeout for all http requests (default: 5).
      attr_accessor :open_timeout

      # Public: IO stream to send debug output too. Off by default.
      #
      #  # for example, this would send all http request information to STDOUT
      #  configuration = Flipper::Cloud::Configuration.new
      #  configuration.debug_output = STDOUT
      attr_accessor :debug_output

      # Public: Instrumenter to use for the Flipper instance returned by
      #         Flipper::Cloud.new (default: Flipper::Instrumenters::Noop).
      #
      #  # for example, to use active support notifications you could do:
      #  configuration = Flipper::Cloud::Configuration.new
      #  configuration.instrumenter = ActiveSupport::Notifications
      attr_accessor :instrumenter

      # Public: The maximum number of events to buffer in memory. If the queue
      # size hits this number, events will be discarded rather than enqueued.
      # This setting exists to allow bounding the memory usage for
      # buffered events.
      attr_accessor :event_capacity

      # Public: The number of seconds between event submissions. The thread
      # submitting events will sleep for event_flush_interval seconds before
      # attempting to submit events again.
      attr_accessor :event_flush_interval

      # Internal: The producer used to buffer events as they happen and
      # eventually ship them to cloud.
      attr_accessor :event_producer

      # Internal: The queue used to buffer events prior to submission. Standard
      # library Queue instance by default. You do not need to care about this.
      attr_accessor :event_queue

      # Internal: The maximum number of events to submit in one request.
      # If there are 500 events to flush and event_batch_size is 100,
      # 5 (500 / 100) HTTP requests will be issued instead of 1 (with all 500).
      # This setting exists to limit the size of payloads submitted to ensure
      # quick processing. You do not need to care about this.
      attr_accessor :event_batch_size

      def initialize(options = {})
        @token = options.fetch(:token)
        @instrumenter = options.fetch(:instrumenter, Instrumenters::Noop)
        @read_timeout = options.fetch(:read_timeout, 5)
        @open_timeout = options.fetch(:open_timeout, 5)
        @event_queue = options.fetch(:event_queue) { Queue.new }
        @event_producer = options.fetch(:event_producer) { Producer.new(self) }
        @event_capacity = options.fetch(:event_capacity, 10_000)
        @event_batch_size = options.fetch(:event_batch_size, 1_000)
        @event_flush_interval = options.fetch(:event_flush_interval, 10)
        @debug_output = options[:debug_output]
        @adapter_block = ->(adapter) { adapter }

        if @event_flush_interval <= 0
          raise ArgumentError, "event_flush_interval must be greater than zero"
        end

        self.url = options.fetch(:url, DEFAULT_URL)
      end

      # Public: Read or customize the http adapter. Calling without a block will
      # perform a read. Calling with a block yields the http_adapter
      # for customization.
      #
      #   # for example, to instrument the http calls, you can wrap the http
      #   # adapter with the intsrumented adapter
      #   configuration = Flipper::Cloud::Configuration.new
      #   configuration.adapter do |adapter|
      #     Flipper::Adapters::Instrumented.new(adapter)
      #   end
      #
      def adapter(&block)
        if block_given?
          @adapter_block = block
        else
          @adapter_block.call(http_adapter)
        end
      end

      # Public: Set url and uri for the http adapter.
      attr_writer :url

      HOSTNAME = begin
                   Socket.gethostbyname(Socket.gethostname).first
                 rescue
                   Socket.gethostname
                 end

      def client
        client_options = {
          read_timeout: @read_timeout,
          open_timeout: @open_timeout,
          debug_output: @debug_output,
          headers: {
            "FEATURE_FLIPPER_TOKEN" => @token,
            "FLIPPER_CONFIG_EVENT_CAPACITY" => event_capacity.to_s,
            "FLIPPER_CONFIG_EVENT_BATCH_SIZE" => event_batch_size.to_s,
            "FLIPPER_CONFIG_EVENT_FLUSH_INTERVAL" => event_flush_interval.to_s,
            "FLIPPER_VERSION" => Flipper::VERSION,
            "FLIPPER_PLATFORM" => "ruby",
            "FLIPPER_PLATFORM_VERSION" => RUBY_VERSION,
            "FLIPPER_HOSTNAME" => HOSTNAME,
            "FLIPPER_PID" => Process.pid.to_s,
            "FLIPPER_TIMESTAMP" => Flipper::Util.timestamp.to_s,
          },
        }
        Flipper::Adapters::Http::Client.new(client_options)
      end

      private

      def http_adapter
        Flipper::Adapters::Http.new(url: @url, client: client)
      end
    end
  end
end

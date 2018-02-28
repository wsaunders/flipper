require "json"
require "thread"
require "forwardable"

module Flipper
  module Cloud
    class Producer
      extend Forwardable

      # Private: Allow disabling sleep between retries for tests.
      attr_accessor :sleep_enabled

      SHUTDOWN = Object.new

      def initialize(configuration)
        @configuration = configuration
        @sleep_enabled = true
        @worker_mutex = Mutex.new
        @timer_mutex = Mutex.new
      end

      def produce(event)
        ensure_threads_alive

        # TODO: Log statistics about dropped events and send to cloud?
        event_queue << [:produce, event] if event_queue.size < event_capacity

        nil
      end

      def deliver
        event_queue << [:deliver, nil]

        nil
      end

      def shutdown
        @timer_thread.exit if @timer_thread
        event_queue << [:shutdown, nil]

        if @worker_thread
          begin
            @worker_thread.join shutdown_timeout
          rescue => exception
            instrument_exception exception
          end
        end

        nil
      end

      private

      def ensure_threads_alive
        ensure_worker_running
        ensure_timer_running
      end

      def ensure_worker_running
        return if worker_running?

        @worker_mutex.synchronize do
          return if worker_running?

          @worker_thread = Thread.new do
            events = []

            loop do
              operation, item = event_queue.pop

              case operation
              when :shutdown
                submit events
                break
              when :produce
                events << item
              when :deliver
                submit events
                events.clear
              else
                # TODO: instrument instead of raise?
                raise "unknown operation: #{operation}"
              end
            end
          end
        end
      end

      def worker_running?
        @worker_thread && @worker_thread.alive?
      end

      # TODO: don't do a deliver if a deliver happened for some other
      # reason recently
      def ensure_timer_running
        return if timer_running?

        @timer_mutex.synchronize do
          return if timer_running?

          @timer_thread = Thread.new do
            loop do
              sleep event_flush_interval
              deliver
            end
          end
        end
      end

      def timer_running?
        @timer_thread && @timer_thread.alive?
      end

      def submit(events)
        events.compact!
        return if events.empty?

        events.each_slice(event_batch_size) do |slice|
          body = JSON.generate(events: slice.map(&:as_json))
          post_url = Flipper::Util.url_for(url, "/events")
          post post_url, body
        end

        nil
      rescue => exception
        instrument_exception(exception)
      end

      class SubmissionError < StandardError
        def self.status_retryable?(status)
          (500..599).cover?(status)
        end

        attr_reader :status

        def initialize(status)
          @status = status
          super("Submission resulted in #{status} http status")
        end
      end

      def post(post_url, body)
        attempts ||= 0

        begin
          attempts += 1
          response = client.post(post_url, body: body)

          http_status = response.code.to_i
          return if http_status == 201

          instrument_response_error(response)
          if SubmissionError.status_retryable?(http_status)
            raise SubmissionError, http_status
          end

          nil
        rescue => exception
          instrument_exception(exception)
          return if attempts >= max_submission_attempts
          sleep sleep_for_attempts(attempts) if sleep_enabled
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
      def sleep_for_attempts(attempts, base: 0.5, max_delay: 2.0)
        sleep_seconds = [base * (2**(attempts - 1)), max_delay].min
        sleep_seconds *= (0.5 * (1 + rand))
        [base, sleep_seconds].max
      end

      def instrument_response_error(response)
        instrumenter.instrument("producer_response_error.flipper", response: response)
      end

      def instrument_exception(exception)
        instrumenter.instrument("producer_exception.flipper", exception: exception)
      end

      CONFIGURATION_DELEGATED_METHODS = [
        :url,
        :client,
        :event_queue,
        :event_capacity,
        :event_batch_size,
        :event_flush_interval,
        :shutdown_timeout,
        :instrumenter,
        :max_submission_attempts,
      ].freeze

      def_delegators :@configuration, *CONFIGURATION_DELEGATED_METHODS

      private(*CONFIGURATION_DELEGATED_METHODS)
    end
  end
end

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
        update_pid
      end

      def produce(event)
        ensure_threads_alive

        if event_queue.size < event_capacity
          event_queue << [:produce, event]
        else # rubocop:disable Style/EmptyElse
          # TODO: Log statistics about dropped events and send to cloud?
        end

        nil
      end

      def deliver
        ensure_threads_alive

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
        # If another thread is starting worker thread, then return early so this
        # thread can enqueue and move on with life.
        return unless @worker_mutex.try_lock

        begin
          return if worker_running?

          update_pid
          @worker_thread = Thread.new do
            events = []

            loop do
              operation, item = event_queue.pop

              case operation
              when :shutdown
                submit events
                events.clear
                break
              when :produce
                events << item
              when :deliver
                submit events
                events.clear
              else
                raise "unknown operation: #{operation}"
              end
            end
          end
        ensure
          @worker_mutex.unlock
        end
      end

      def worker_running?
        @worker_thread && @pid == Process.pid && @worker_thread.alive?
      end

      def ensure_timer_running
        # If another thread is starting timer thread, then return early so this
        # thread can enqueue and move on with life.
        return unless @timer_mutex.try_lock

        begin
          return if timer_running?

          update_pid
          @timer_thread = Thread.new do
            loop do
              sleep event_flush_interval

              # TODO: don't do a deliver if a deliver happened for some other
              # reason recently
              deliver
            end
          end
        ensure
          @timer_mutex.unlock
        end
      end

      def timer_running?
        @timer_thread && @pid == Process.pid && @timer_thread.alive?
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
        def self.retry?(status)
          (500..599).cover?(status)
        end

        attr_reader :status

        def initialize(status)
          @status = status
          super("Submission resulted in #{status} http status")
        end
      end

      def post(post_url, body)
        with_retry do
          response = client.post(post_url, body: body)
          status = response.code.to_i

          if status != 201
            instrument_response_error(response)
            raise SubmissionError, status if SubmissionError.retry?(status)
          end
        end
      end

      def with_retry
        attempts ||= 0

        begin
          attempts += 1
          yield
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

      def update_pid
        @pid = Process.pid
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

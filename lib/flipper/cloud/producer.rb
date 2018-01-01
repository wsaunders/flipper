require "json"
require "socket"
require "thread"
require "forwardable"

module Flipper
  module Cloud
    class Producer
      extend Forwardable

      SHUTDOWN = Object.new
      HOSTNAME = begin
                   Socket.gethostbyname(Socket.gethostname).first
                 rescue
                   Socket.gethostname
                 end

      def initialize(configuration)
        @configuration = configuration
      end

      def produce(event)
        ensure_threads_alive

        # TODO: Stop enqueueing events if shutting down?
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
        @worker_thread.join if @worker_thread

        nil
      end

      private

      def ensure_threads_alive
        @worker_thread = create_thread unless @worker_thread && @worker_thread.alive?
        @timer_thread = create_timer_thread unless @timer_thread && @timer_thread.alive?
      end

      def create_thread
        Thread.new do
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
              raise "unknown operation: #{operation}"
            end
          end
        end
      end

      def create_timer_thread
        Thread.new do
          loop do
            sleep event_flush_interval
            deliver
          end
        end
      end

      def submit(events)
        events.compact!
        return if events.empty?

        events.each_slice(event_batch_size) do |slice|
          attributes = {
            events: slice.map(&:as_json),
            event_capacity: event_capacity,
            event_batch_size: event_batch_size,
            event_flush_interval: event_flush_interval,
            version: Flipper::VERSION,
            platform: "ruby",
            platform_version: RUBY_VERSION,
            hostname: HOSTNAME,
            pid: Process.pid,
            client_timestamp: Cloud.timestamp,
          }
          body = JSON.generate(attributes)

          # TODO: Handle failures (not 201) by retrying for a period of time or
          # maximum number of retries (with backoff).
          response = client.post("/events", body)
          instrument_response_error(response) if response.code.to_i != 201

          nil
        end
      rescue => exception
        instrument_exception(exception)
      end

      def instrument_response_error(response)
        payload = {
          response: response,
        }
        instrumenter.instrument("producer_submission_response_error.flipper", payload)
      end

      def instrument_exception(exception)
        payload = {
          exception: exception,
        }
        instrumenter.instrument("producer_submission_exception.flipper", payload)
      end

      def_delegators :@configuration,
                     :client,
                     :event_queue,
                     :event_capacity,
                     :event_batch_size,
                     :event_flush_interval,
                     :instrumenter
    end
  end
end

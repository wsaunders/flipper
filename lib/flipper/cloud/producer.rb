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
        ensure_thread_alive

        # TODO: Stop enqueueing events if shutting down?
        # TODO: Log statistics about dropped events and send to cloud?
        event_queue << event if event_queue.size < event_capacity
      end

      def shutdown
        event_queue << SHUTDOWN
        @thread.join
      end

      private

      def ensure_thread_alive
        @thread = create_thread unless @thread && @thread.alive?
      end

      def create_thread
        Thread.new do
          shutdown = false

          loop do
            begin
              sleep event_flush_interval

              events = []
              size = event_queue.size
              size.times { events << event_queue.pop(true) }
              shutdown, events = events.partition { |event| event == SHUTDOWN }
              submit_events events
            rescue # rubocop:disable Lint/HandleExceptions
              # TODO: Do something with boom like log or report to cloud.
            ensure
              # TODO: Flush any remaining events here?
              break if shutdown
            end
          end
        end
      end

      def submit_events(events)
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
            client_timestamp: Instrumenter.timestamp,
          }
          body = JSON.generate(attributes)
          # TODO: Handle failures (not 201) by retrying for a period of time or
          # maximum number of retries (with backoff).
          # TODO: Instrument failures so we can log them or whatever.
          client.post("/events", body)
        end
      end

      def_delegators :@configuration,
                     :client,
                     :event_queue,
                     :event_capacity,
                     :event_batch_size,
                     :event_flush_interval
    end
  end
end

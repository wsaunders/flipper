require 'json'
require 'thread'
require 'socket'

module Flipper
  module Cloud
    class Instrumenter
      extend Forwardable

      def self.clock_milliseconds
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      end

      SHUTDOWN = Object.new

      def initialize(configuration)
        @configuration = configuration
        @thread = create_thread
      end

      def instrument(name, payload = {}, &block)
        result = instrumenter.instrument(name, payload, &block)
        add Event.new_from_name_and_payload(name: name, payload: payload)
        result
      end

      def shutdown
        event_queue << SHUTDOWN
        @thread.join
      end

      private

      def_delegators :@configuration,
                     :client,
                     :instrumenter,
                     :event_capacity,
                     :event_queue,
                     :event_flush_interval

      def add(event)
        # TODO: Ensure the worker thread is alive and create new one if not.
        # TODO: Ensure there is capacity to add event to queue and keep track of
        # discarded items and report that to cloud in some way
        # TODO: Stop enqueueing events if shutting down?
        event_queue << event
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
              submit_events(events)
            rescue => boom
              p boom: boom, response: response, body: response.body
              # TODO: do something with boom like log or report to cloud
            ensure
              # TODO: flush any remaining events here?
              break if shutdown
            end
          end
        end
      end

      def submit_events(events)
        return if events.empty?

        # TODO: Bound the number of events per request.
        attributes = {
          events: events.map(&:as_json),
          event_capacity: event_capacity,
          event_flush_interval: event_flush_interval,
          version: Flipper::VERSION,
          platform: "ruby",
          platform_version: RUBY_VERSION,
          hostname: Socket.gethostname,
          pid: Process.pid,
          client_timestamp: Instrumenter.clock_milliseconds,
        }
        body = JSON.generate(attributes)
        response = client.post("/events", body)

        # TODO: never raise here, just report some statistic instead
        # TODO: Handle failures (not 201) by retrying for a period of time or
        # maximum number of retries.
        raise "Response error: #{response}" if response.code.to_i / 100 != 2
      end
    end
  end
end

require 'flipper/cloud/instrumenter/event'

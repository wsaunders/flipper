require 'json'
require 'thread'
require 'flipper/cloud/instrumenter/event'

module Flipper
  module Cloud
    class Instrumenter
      extend Forwardable

      SHUTDOWN = Object.new

      def initialize(configuration)
        @configuration = configuration
        @thread = create_worker_thread
      end

      def instrument(name, payload = {}, &block)
        # TODO: ensure thread exists and is alive (ala ruby-kafka)
        result = instrumenter.instrument(name, payload, &block)
        add Event.new(name, payload)
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
        event_queue << event
      end

      def create_worker_thread
        Thread.new do
          shutdown = false

          loop do
            begin
              sleep event_flush_interval

              events = []
              size = event_queue.size
              size.times { events << event_queue.pop(true) }

              shutdown, events = events.partition { |event| event == SHUTDOWN }

              unless events.empty?
                # TODO: Bound the number of events per request.
                body = JSON.generate({
                  events: events.map(&:as_json),
                })
                response = client.post("/events", body)
                if response.code.to_i / 100 != 2
                  raise "Response error: #{response}"
                end
              end
            rescue => boom
              p boom: boom
              # TODO: do something with boom like log or report to cloud
            ensure
              break if shutdown
            end
          end
        end
      end
    end
  end
end

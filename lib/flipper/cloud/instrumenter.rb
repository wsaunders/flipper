require 'forwardable'
require 'thread'
require 'flipper/cloud/instrumenter/event'

module Flipper
  module Cloud
    class Instrumenter
      extend Forwardable

      def_delegators :@configuration,
        :event_capacity,
        :event_flush_interval,
        :event_queue,
        :client

      attr_reader :instrumenter

      def initialize(configuration)
        @configuration = configuration
      end

      def instrument(name, payload = {}, &block)
        result = instrumenter.instrument(name, payload, &block)
        add Event.new(name, payload)
        result
      end

      def add(event)
        if capacity?
          event_queue << event
        else
          # TODO: drop events? log? warn?
        end
      end

      private

      def capacity?
        event_queue.size < event_capacity
      end

      def instrumenter
        @configuration.instrumenter
      end
    end
  end
end

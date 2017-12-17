require 'flipper/cloud/instrumenter/event'

module Flipper
  module Cloud
    class Instrumenter
      attr_reader :instrumenter

      def initialize(configuration)
        @configuration = configuration
      end

      def instrument(name, payload = {}, &block)
        result = instrumenter.instrument(name, payload, &block)
        @configuration.event_queue << Event.new(name, payload)
        result
      end

      private

      def instrumenter
        @configuration.instrumenter
      end
    end
  end
end

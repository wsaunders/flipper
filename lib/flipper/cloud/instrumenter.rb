require 'thread'
require 'flipper/cloud/instrumenter/event'
require 'flipper/cloud/instrumenter/processor'

module Flipper
  module Cloud
    class Instrumenter
      attr_reader :instrumenter

      def initialize(configuration)
        @configuration = configuration
        @processor = Processor.new(configuration)
      end

      def instrument(name, payload = {}, &block)
        result = instrumenter.instrument(name, payload, &block)
        @processor.add Event.new(name, payload)
        result
      end

      def instrumenter
        @configuration.instrumenter
      end
    end
  end
end

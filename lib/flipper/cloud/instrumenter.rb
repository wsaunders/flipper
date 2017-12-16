require 'thread'

module Flipper
  module Cloud
    class Instrumenter
      attr_reader :instrumenter

      def initialize(instrumenter)
        @instrumenter = instrumenter
      end

      def instrument(name, payload = {}, &block)
        @instrumenter.instrument(name, payload, &block)
      end
    end
  end
end

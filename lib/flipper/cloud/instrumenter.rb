require 'thread'

module Flipper
  module Cloud
    class Instrumenter
      attr_reader :instrumenter

      def initialize(configuration)
        @configuration = configuration
      end

      def instrument(name, payload = {}, &block)
        @configuration.instrumenter.instrument(name, payload, &block)
      end
    end
  end
end

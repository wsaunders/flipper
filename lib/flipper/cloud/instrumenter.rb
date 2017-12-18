require 'flipper/cloud/instrumenter/event'
require 'flipper/cloud/instrumenter/worker'

module Flipper
  module Cloud
    class Instrumenter
      extend Forwardable

      def initialize(configuration)
        @configuration = configuration
        @worker = Worker.new(@configuration.event_queue, @configuration.client)
      end

      def instrument(name, payload = {}, &block)
        ensure_worker_running
        result = instrumenter.instrument(name, payload, &block)
        event_queue << Event.new(name, payload)
        result
      end

      private

      def_delegators :@configuration, :instrumenter, :event_queue

      def ensure_worker_running
        @thread = nil unless @thread && @thread.alive?
        @thread = Thread.new { worker.run }
      end
    end
  end
end

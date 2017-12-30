require 'json'
require 'thread'
require 'socket'
require 'flipper/cloud/producer'
require 'flipper/cloud/instrumenter/event'

module Flipper
  module Cloud
    class Instrumenter
      extend Forwardable

      def self.timestamp(now = Time.now)
        (now.to_f * 1_000).floor
      end

      def initialize(configuration)
        @configuration = configuration
        @producer = Producer.new(configuration)
      end

      def instrument(name, payload = {}, &block)
        result = instrumenter.instrument(name, payload, &block)

        if name == Flipper::Feature::InstrumentationName
          @producer.produce payload_to_event(payload)
        end

        result
      end

      private

      def_delegator :@configuration, :instrumenter

      def payload_to_event(payload)
        attributes = {
          type: "enabled",
          dimensions: {
            "feature" => payload[:feature_name].to_s,
            "result" => payload[:result].to_s,
          },
          timestamp: Instrumenter.timestamp,
        }

        thing = payload[:thing]
        attributes[:dimensions]["flipper_id"] = thing.value if thing

        Event.new(attributes)
      end
    end
  end
end

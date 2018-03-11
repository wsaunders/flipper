require "delegate"
require "flipper/event"
require "flipper/util"
require "flipper/cloud/producer"

module Flipper
  module Cloud
    class Client < SimpleDelegator
      attr_reader :configuration
      attr_reader :flipper
      attr_reader :producer

      def initialize(configuration:)
        @configuration = configuration
        @producer = build_producer
        @flipper = build_flipper

        connect_producer_to_instrumentation
        super @flipper
      end

      private

      def build_flipper
        Flipper.new(configuration.adapter, instrumenter: configuration.instrumenter)
      end

      def build_producer
        default_producer_options = {
          instrumenter: @configuration.instrumenter,
          client: @configuration.client,
        }
        provided_producer_options = @configuration.producer_options
        producer_options = default_producer_options.merge(provided_producer_options)
        Producer.new(producer_options)
      end

      def connect_producer_to_instrumentation
        configuration.instrumenter.subscribe(Flipper::Feature::InstrumentationName) do |*args|
          _name, _start, _finish, _id, payload = args
          attributes = {
            type: "enabled",
            dimensions: {
              "feature" => payload[:feature_name].to_s,
              "result" => payload[:result].to_s,
            },
            timestamp: Flipper::Util.timestamp,
          }

          thing = payload[:thing]
          attributes[:dimensions]["flipper_id"] = thing.value if thing

          event = Flipper::Event.new(attributes)
          @producer.produce event
        end
      end
    end
  end
end

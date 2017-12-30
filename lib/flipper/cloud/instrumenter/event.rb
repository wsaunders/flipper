module Flipper
  module Cloud
    class Instrumenter
      class Event
        attr_reader :type, :timestamp, :dimensions

        # Operations with a name that we want to normalize.
        ABNORMAL_OPERATIONS = {
          enabled?: :enabled,
        }.freeze

        DEFAULT_OPERATION = :unknown
        FEATURE_KEY = "feature".freeze
        FLIPPER_ID_KEY = "flipper_id".freeze
        RESULT_KEY = "result".freeze
        ENABLED_TYPE = "enabled".freeze

        def self.from_hash(hash)
          attributes = {
            type: hash.fetch("type"),
            timestamp: hash.fetch("timestamp"),
            dimensions: hash.fetch("dimensions"),
          }
          new attributes
        end

        def self.new_from_name_and_payload(attributes = {})
          # TODO: This method should always return event. Move early return
          # logic to caller.
          name = attributes.fetch(:name)
          payload = attributes.fetch(:payload)
          return unless name == Flipper::Feature::InstrumentationName

          feature = payload[:feature_name]
          return unless feature

          dimensions = {}
          dimensions[FEATURE_KEY] = feature.to_s

          type = type_from_payload(payload)
          return unless type == ENABLED_TYPE

          thing = payload[:thing]
          dimensions[FLIPPER_ID_KEY] = thing.value if thing

          if payload.key?(:result)
            dimensions[RESULT_KEY] = payload[:result].to_s
          end

          attributes = {
            type: type,
            dimensions: dimensions,
            timestamp: Instrumenter.timestamp,
          }
          new(attributes)
        end

        def self.type_from_payload(payload)
          operation = payload[:operation] || DEFAULT_OPERATION
          ABNORMAL_OPERATIONS.fetch(operation, operation).to_s
        end

        def initialize(attributes = {})
          @type = attributes.fetch(:type)
          @dimensions = attributes.fetch(:dimensions) { {} }
          @timestamp = attributes.fetch(:timestamp) { Instrumenter.timestamp }
        end

        def as_json
          @as_json ||= {
            type: type,
            timestamp: timestamp,
            dimensions: dimensions,
          }
        end
      end
    end
  end
end

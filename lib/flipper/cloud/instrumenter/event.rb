module Flipper
  module Cloud
    class Instrumenter
      class Event
        attr_reader :type, :timestamp, :dimensions

        # Operations with a name that we want to normalize.
        ABNORMAL_OPERATIONS = {
          :enabled? => :enabled,
        }

        DEFAULT_OPERATION = :unknown
        FEATURE_KEY = "feature".freeze
        FLIPPER_ID_KEY = "flipper_id".freeze
        RESULT_KEY = "result".freeze

        def initialize(name, payload)
          @timestamp = Time.now.to_i
          @name = name
          @payload = payload
          @dimensions = {}

          operation = payload[:operation] || DEFAULT_OPERATION
          @type = ABNORMAL_OPERATIONS.fetch(operation, operation).to_s

          feature = payload[:feature_name]
          if feature
            @dimensions[FEATURE_KEY] = feature.to_s

            if operation == :enabled?
              if thing = payload[:thing]
                @dimensions[FLIPPER_ID_KEY] = thing.value
              end

              if payload.key?(:result)
                @dimensions[RESULT_KEY] = payload[:result].to_s
              end
            end
          end
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

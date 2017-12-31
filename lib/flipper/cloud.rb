require "flipper/cloud/configuration"

module Flipper
  module Cloud
    def self.timestamp(now = Time.now)
      (now.to_f * 1_000).floor
    end

    # Public: Returns a new Flipper instance with an http adapter correctly
    # configured for flipper cloud.
    #
    # token - The String token for the environment from the website.
    # options - The Hash of options. See Flipper::Cloud::Configuration.
    # block - The block that configuration will be yielded to allowing you to
    #         customize this cloud instance and its adapter.
    def self.new(token, options = {})
      configuration = Configuration.new(options.merge(token: token))
      yield configuration if block_given?

      configuration.instrumenter.subscribe(Flipper::Feature::InstrumentationName) do |name, start, finish, id, payload|
        attributes = {
          type: "enabled",
          dimensions: {
            "feature" => payload[:feature_name].to_s,
            "result" => payload[:result].to_s,
          },
          timestamp: Cloud.timestamp,
        }

        thing = payload[:thing]
        attributes[:dimensions]["flipper_id"] = thing.value if thing

        event = Event.new(attributes)
        producer = configuration.event_producer
        producer.produce event
      end

      Flipper.new(configuration.adapter, instrumenter: configuration.instrumenter)
    end
  end
end

require "flipper/cloud/configuration"
require "flipper/event"

module Flipper
  module Cloud
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
        producer = configuration.event_producer
        producer.produce event
      end

      Flipper.new(configuration.adapter, instrumenter: configuration.instrumenter)
    end
  end
end

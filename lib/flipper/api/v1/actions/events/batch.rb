require "forwardable"

module Flipper
  module Api
    module V1
      module Actions
        class Events < Api::Action
          class Batch
            extend Forwardable

            attr_reader :request,
                        :pid, :hostname,
                        :version, :platform, :platform_version,
                        :event_capacity, :event_flush_interval,
                        :client_timestamp, :timestamp,
                        :events

            def_delegators :@request, :ip, :user_agent

            def initialize(request)
              @request = request

              @pid = data.fetch("pid")
              @hostname = data.fetch("hostname")

              @version = data.fetch("version")
              @platform = data.fetch("platform")
              @platform_version = data.fetch("platform_version")

              @event_capacity = data.fetch("event_capacity")
              @event_flush_interval = data.fetch("event_flush_interval")

              @client_timestamp = data.fetch("client_timestamp")
              @timestamp = Cloud::Instrumenter.timestamp

              @events = data.fetch("events").map do |hash|
                Cloud::Instrumenter::Event.from_hash(hash)
              end
            end

            def data
              @data ||= JSON.parse(request.body.read)
            end
          end
        end
      end
    end
  end
end

module Flipper
  module Api
    module V1
      module Actions
        class Events < Api::Action
          class Batch
            attr_reader :ip, :pid, :hostname,
                        :user_agent, :version, :platform, :platform_version,
                        :event_capacity, :event_flush_interval,
                        :client_timestamp, :timestamp,
                        :events

            def initialize(attributes = {})
              @ip = attributes.fetch(:ip)
              @pid = attributes.fetch(:pid)
              @hostname = attributes.fetch(:hostname)

              @user_agent = attributes.fetch(:user_agent)
              @version = attributes.fetch(:version)
              @platform = attributes.fetch(:platform)
              @platform_version = attributes.fetch(:platform_version)

              @event_capacity = attributes.fetch(:event_capacity)
              @event_flush_interval = attributes.fetch(:event_flush_interval)

              @client_timestamp = attributes.fetch(:client_timestamp)
              @timestamp = attributes.fetch(:timestamp) do
                Cloud::Instrumenter.clock_milliseconds
              end

              @events = attributes.fetch(:events)
            end
          end
        end
      end
    end
  end
end

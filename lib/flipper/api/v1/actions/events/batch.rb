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
                        :event_capacity, :event_flush_interval, :event_batch_size,
                        :client_timestamp, :timestamp,
                        :events,
                        :errors

            def_delegators :@request, :ip, :user_agent

            def initialize(request)
              @request = request

              @pid = @request.get_header("HTTP_FLIPPER_PID")
              @hostname = @request.get_header("HTTP_FLIPPER_HOSTNAME")

              @version = @request.get_header("HTTP_FLIPPER_VERSION")
              @platform = @request.get_header("HTTP_FLIPPER_PLATFORM")
              @platform_version = @request.get_header("HTTP_FLIPPER_PLATFORM_VERSION")

              @event_capacity = @request.get_header("HTTP_FLIPPER_CONFIG_EVENT_CAPACITY")
              @event_flush_interval = @request.get_header("HTTP_FLIPPER_CONFIG_EVENT_FLUSH_INTERVAL") # rubocop:disable Style/LineLength
              @event_batch_size = @request.get_header("HTTP_FLIPPER_CONFIG_EVENT_BATCH_SIZE")

              @client_timestamp = @request.get_header("HTTP_FLIPPER_TIMESTAMP")
              @timestamp = Flipper.timestamp

              @raw_events = data.fetch("events") { [] }
              @events = @raw_events.map { |hash| Cloud::Event.from_hash(hash) }

              @errors = []
              validate
            end

            def valid?
              @errors.empty?
            end

            def data
              @data ||= JSON.parse(request.body.read)
            end

            private

            def validate
              validate_client_information
              validate_platform
              validate_config
              validate_events
            end

            def validate_client_information
              if @pid.nil?
                @errors << ["Flipper-Pid is required"]
              end

              if @hostname.nil?
                @errors << ["Flipper-Hostname is required"]
              end

              if @client_timestamp.nil?
                @errors << ["Flipper-Timestamp header is required"]
              end
            end

            def validate_platform
              if @version.nil?
                @errors << ["Flipper-Version is required"]
              end

              if @platform.nil?
                @errors << ["Flipper-Platform is required"]
              end

              if @platform_version.nil?
                @errors << ["Flipper-Platform Version is required"]
              end
            end

            def validate_config
              if @event_capacity.nil?
                @errors << ["Flipper-Config-Event-Capacity-Config header is required"]
              end

              if @event_flush_interval.nil?
                @errors << ["Flipper-Config-Event-Flush-Interval header is required"]
              end

              if @event_batch_size.nil?
                @errors << ["Flipper-Config-Event-Batch-Size header is required"]
              end
            end

            def validate_events
              if @raw_events.empty?
                @errors << ["At least one event is required"]
              end
            end
          end
        end
      end
    end
  end
end

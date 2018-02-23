require "forwardable"
require "flipper/event"
require "flipper/util"

module Flipper
  module Api
    module V1
      module Actions
        class Events < Api::Action
          class Batch
            extend Forwardable

            attr_reader :request,
                        :pid, :thread, :hostname,
                        :version, :platform, :platform_version,
                        :event_capacity, :event_flush_interval, :event_batch_size,
                        :client_timestamp, :timestamp,
                        :events,
                        :errors

            def_delegators :@request, :ip, :user_agent

            def initialize(request)
              @request = request

              assign_client_details
              assign_event_config_details

              @timestamp = Flipper::Util.timestamp
              @raw_events = data.fetch("events") { [] }
              @events = @raw_events.map { |hash| Flipper::Event.from_hash(hash) }

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

            def assign_client_details
              @pid = @request.env["HTTP_FLIPPER_PID"]
              @thread = @request.env["HTTP_FLIPPER_THREAD"]
              @hostname = @request.env["HTTP_FLIPPER_HOSTNAME"]

              @version = @request.env["HTTP_FLIPPER_VERSION"]
              @platform = @request.env["HTTP_FLIPPER_PLATFORM"]
              @platform_version = @request.env["HTTP_FLIPPER_PLATFORM_VERSION"]

              @client_timestamp = @request.env["HTTP_FLIPPER_TIMESTAMP"]
            end

            def assign_event_config_details
              @event_capacity = @request.env["HTTP_FLIPPER_CONFIG_EVENT_CAPACITY"]
              @event_flush_interval = @request.env["HTTP_FLIPPER_CONFIG_EVENT_FLUSH_INTERVAL"] # rubocop:disable Metrics/LineLength
              @event_batch_size = @request.env["HTTP_FLIPPER_CONFIG_EVENT_BATCH_SIZE"]
            end

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

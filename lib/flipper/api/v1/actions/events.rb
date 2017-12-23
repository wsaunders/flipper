require 'flipper/api/action'
require 'flipper/cloud/instrumenter'
require 'flipper/cloud/instrumenter/event'
require 'flipper/api/v1/actions/events/batch'

module Flipper
  module Api
    module V1
      module Actions
        class Events < Api::Action
          route %r{events/?\Z}

          def post
            # TODO: validate the entire request before we try to do anything
            # with it
            events = json_params.fetch('events').map do |hash|
              Cloud::Instrumenter::Event.from_hash(hash)
            end
            attributes = {
              ip: request.ip,
              pid: json_params.fetch('pid'),
              hostname: json_params.fetch('hostname'),
              user_agent: request.user_agent,
              version: json_params.fetch('version'),
              platform: json_params.fetch('platform'),
              platform_version: json_params.fetch('platform_version'),
              event_capacity: json_params.fetch('event_capacity'),
              event_flush_interval: json_params.fetch('event_flush_interval'),
              client_timestamp: json_params.fetch('client_timestamp'),
              timestamp: Cloud::Instrumenter.clock_milliseconds,
              events: events,
            }
            batch = Batch.new(attributes)
            event_receiver.call(batch)
            json_response({}, 201)
          end
        end
      end
    end
  end
end

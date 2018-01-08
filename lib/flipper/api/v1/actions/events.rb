require 'flipper/api/action'
require 'flipper/api/v1/actions/events/batch'

module Flipper
  module Api
    module V1
      module Actions
        class Events < Api::Action
          route %r{events/?\Z}

          def post
            batch = Batch.new(request)

            if batch.valid?
              event_receiver.call(batch)
              json_response({}, 201)
            else
              json_error_response(:batch_invalid, batch.errors)
            end
          end
        end
      end
    end
  end
end

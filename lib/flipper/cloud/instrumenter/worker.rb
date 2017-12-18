require 'json'
require 'flipper/cloud/instrumenter/event'

module Flipper
  module Cloud
    class Instrumenter
      class Worker
        Shutdown = Object.new

        class Batch
          def initialize(items)
            @items = items
          end

          def submit(client)
            return if @items.empty?

            body = JSON.dump({
              events: @items.map(&:as_json),
            })
            client.post("/events", body)
          rescue
            # TODO: retry?
          end
        end

        attr_reader :queue, :client, :buffer

        def initialize(queue, client)
          @queue = queue
          @client = client
          @buffer = []
        end

        def shutdown
          queue << Shutdown
        end

        def run
          loop do
            event = queue.pop

            case event
            when Shutdown
              flush
              break
            when Event
              @buffer << event
              flush if @buffer.size >= 100
            else
              raise "unknown event: #{event.inspect}"
            end
          end
        end

        private

        def flush
          batch = Batch.new(@buffer)
          batch.submit(client)
          @buffer = []
        end
      end
    end
  end
end

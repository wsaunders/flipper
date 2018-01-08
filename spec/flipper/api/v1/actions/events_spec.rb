require 'helper'
require 'flipper/api/v1/actions/events'
require 'flipper/event_receivers/memory'

RSpec.describe Flipper::Api::V1::Actions::Events do
  let(:event_receiver) { Flipper::EventReceivers::Memory.new }
  let(:app) { build_api(flipper, event_receiver: event_receiver) }

  describe 'post' do
    context 'valid' do
      it 'responds with 201' do
        now = Flipper.timestamp
        client_timestamp = now - 100
        timestamp = now - 1000
        env = {
          "CONTENT_TYPE" => "application/json",
          "HTTP_USER_AGENT" => "Flipper",
          "Flipper-Pid" => "123",
          "Flipper-Hostname" => "foobar.com",
          "Flipper-Version" => Flipper::VERSION,
          "Flipper-Platform" => "ruby",
          "Flipper-Platform-Version" => "2.3.3",
          "Flipper-Config-Event-Capacity" => "10000",
          "Flipper-Config-Event-Flush-Interval" => "10",
          "Flipper-Config-Event-Batch-Size" => "1000",
          "Flipper-Timestamp" => client_timestamp.to_s,
        }
        dimensions = {
          "feature" => "foo",
          "flipper_id" => "User;23",
          "result" => "true",
        }
        attributes = {
          events: [
            { type: 'enabled', dimensions: dimensions, timestamp: timestamp },
          ],
        }
        body = JSON.generate(attributes)
        post '/events', body, env

        expect(last_response.status).to be(201)

        expected_response = {}
        expect(json_response).to eq(expected_response)
        expect(event_receiver.size).to be(1)

        batch = event_receiver.first
        expect(batch).not_to be(nil)
        expect(batch.ip).to eq("127.0.0.1")
        expect(batch.pid).to eq("123")
        expect(batch.hostname).to eq("foobar.com")
        expect(batch.user_agent).to eq("Flipper")
        expect(batch.version).to eq(Flipper::VERSION)
        expect(batch.platform).to eq("ruby")
        expect(batch.platform_version).to eq("2.3.3")
        expect(batch.event_capacity).to eq("10000")
        expect(batch.event_batch_size).to eq("1000")
        expect(batch.event_flush_interval).to eq("10")
        expect(batch.client_timestamp).to eq(client_timestamp.to_s)
        expect(batch.timestamp >= now).to be(true)
        expect(batch.events.size).to be(1)

        event = batch.events.first
        expect(event.type).to eq("enabled")
        expect(event.dimensions).to eq(dimensions)
        expect(event.timestamp).to eq(timestamp)
      end
    end

    context 'invalid' do
      it 'responds with 422 and errors' do
        env = {
          "CONTENT_TYPE" => "application/json",
        }
        post '/events', '{}', env
        expect(last_response.status).to be(422)
      end
    end
  end
end

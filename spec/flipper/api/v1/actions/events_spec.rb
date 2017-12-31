require 'helper'
require 'flipper/api/v1/actions/events'
require 'flipper/event_receivers/memory'

RSpec.describe Flipper::Api::V1::Actions::Events do
  let(:event_receiver) { Flipper::EventReceivers::Memory.new }
  let(:app) { build_api(flipper, event_receiver: event_receiver) }

  describe 'post' do
    it 'responds with 201' do
      now = Flipper::Cloud.timestamp
      client_timestamp = now - 100
      timestamp = now - 1000
      env = {
        'CONTENT_TYPE' => 'application/json',
        'HTTP_USER_AGENT' => 'Flipper',
      }
      dimensions = {
        'feature' => 'foo',
        'flipper_id' => 'User;23',
        'result' => 'true',
      }
      attributes = {
        pid: 123,
        hostname: 'foobar.com',
        version: Flipper::VERSION,
        platform: 'ruby',
        platform_version: '2.3.3',
        event_capacity: 10_000,
        event_batch_size: 1_000,
        event_flush_interval: 10,
        client_timestamp: client_timestamp,
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
      expect(batch.pid).to be(123)
      expect(batch.hostname).to eq("foobar.com")
      expect(batch.user_agent).to eq("Flipper")
      expect(batch.version).to eq("0.11.0")
      expect(batch.platform).to eq("ruby")
      expect(batch.platform_version).to eq("2.3.3")
      expect(batch.event_capacity).to eq(10000)
      expect(batch.event_flush_interval).to eq(10)
      expect(batch.client_timestamp).to eq(client_timestamp)
      expect(batch.timestamp >= now).to be(true)
      expect(batch.events.size).to be(1)

      event = batch.events.first
      expect(event.type).to eq("enabled")
      expect(event.dimensions).to eq(dimensions)
      expect(event.timestamp).to eq(timestamp)
    end
  end
end

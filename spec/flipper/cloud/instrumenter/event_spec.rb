require 'helper'
require 'flipper/cloud/instrumenter/event'

RSpec.describe Flipper::Cloud::Instrumenter::Event do
  let(:type) { "enabled" }
  let(:name) { "feature_operation.flipper" }
  let(:dimensions) do
    {
      "feature" => "foo",
      "flipper_id" => "User;23",
      "result" => "true",
    }
  end
  let(:payload) do
    {
      result: true,
      feature_name: :foo,
      operation: :enabled?,
      gate_name: :percentage_of_actors,
      thing: Flipper::Types::Actor.new(Flipper::Actor.new("User;23")),
    }
  end
  let(:as_json_hash) do
    {
      "type" => type,
      "timestamp" => timestamp,
      "dimensions" => dimensions,
    }
  end
  let(:timestamp) { Flipper::Cloud::Instrumenter.timestamp }

  describe '.from_hash' do
    it 'sets type' do
      instance = described_class.from_hash(as_json_hash)
      expect(instance.type).to eq(type)
    end

    it 'sets dimensions' do
      instance = described_class.from_hash(as_json_hash)
      expect(instance.dimensions).to eq(dimensions)
    end

    it 'sets dimensions' do
      instance = described_class.from_hash(as_json_hash)
      expect(instance.timestamp).to eq(timestamp)
    end
  end

  describe '.new_from_name_and_payload' do
    it 'defaults timestamp to now' do
      instance = described_class.new_from_name_and_payload(name: name, payload: payload)
      expect(instance.timestamp).to be(instance.timestamp)
    end

    it 'knows type' do
      instance = described_class.new_from_name_and_payload(name: name, payload: payload)
      expect(instance.type).to eq("enabled")
    end

    it 'knows dimensions' do
      instance = described_class.new_from_name_and_payload(name: name, payload: payload)
      expect(instance.dimensions).to eq("feature" => "foo",
                                        "flipper_id" => "User;23",
                                        "result" => "true")
    end
  end

  describe '#initialize' do
    it 'defaults timestamp' do
      now = Flipper::Cloud::Instrumenter.timestamp
      instance = described_class.new(type: type)
      expect(instance.timestamp >= now).to be(true)
    end

    it 'defaults dimensions to empty hash' do
      instance = described_class.new(type: type)
      expect(instance.dimensions).to eq({})
    end

    it 'sets type' do
      instance = described_class.new(type: type)
      expect(instance.type).to be(type)
    end

    it 'allows setting dimensions' do
      dimensions = {
        "foo" => "bar",
      }
      instance = described_class.new(type: type, dimensions: dimensions)
      expect(instance.dimensions).to eq(dimensions)
    end

    it 'allows setting timestamp' do
      timestamp = Flipper::Cloud::Instrumenter.timestamp
      instance = described_class.new(type: type, timestamp: timestamp)
      expect(instance.timestamp).to eq(timestamp)
    end
  end
end

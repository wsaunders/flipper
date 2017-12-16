require 'helper'
require 'flipper/cloud/instrumenter/event'

RSpec.describe Flipper::Cloud::Instrumenter::Event do
  let(:name) { "feature_operation.flipper" }
  let(:payload) {
    {
      result: true,
      feature_name: :foo,
      operation: :enabled?,
      gate_name: :percentage_of_actors,
      thing: Flipper::Types::Actor.new(Flipper::Actor.new("User;23")),
    }
  }

  it 'knows timestamp' do
    instance = described_class.new(name, payload)
    expect(instance.timestamp).to be_instance_of(Fixnum)
    expect(instance.timestamp).to be(instance.timestamp)
  end

  it 'knows type' do
    instance = described_class.new(name, payload)
    expect(instance.type).to eq("enabled")
  end

  it 'knows dimensions' do
    instance = described_class.new(name, payload)
    expect(instance.dimensions).to eq({
      "feature" => "foo",
      "flipper_id" => "User;23",
      "result" => "true",
    })
  end
end

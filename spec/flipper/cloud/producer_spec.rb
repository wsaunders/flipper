require 'helper'
require 'flipper/cloud'
require 'flipper/cloud/event'
require 'flipper/cloud/configuration'
require 'flipper/cloud/producer'

RSpec.describe Flipper::Cloud::Producer do
  let(:configuration) do
    attributes = {
      token: "asdf",
      event_capacity: 10,
      event_batch_size: 5,
    }
    Flipper::Cloud::Configuration.new(attributes)
  end

  let(:event) do
    attributes = {
      type: "enabled",
      dimensions: {
        "feature" => "foo",
        "flipper_id" => "User;23",
        "result" => "true",
      },
      timestamp: Flipper::Cloud.timestamp,
    }
    Flipper::Cloud::Event.new(attributes)
  end

  subject { configuration.event_producer }

  after do
    subject.shutdown
  end

  it 'creates thread on produce and kills on shutdown' do
    stub_request(:post, "https://www.featureflipper.com/adapter/events")

    expect(subject.instance_variable_get("@worker_thread")).to be_nil
    expect(subject.instance_variable_get("@timer_thread")).to be_nil

    subject.produce(event)

    expect(subject.instance_variable_get("@worker_thread")).to be_instance_of(Thread)
    expect(subject.instance_variable_get("@timer_thread")).to be_instance_of(Thread)

    subject.shutdown

    expect(subject.instance_variable_get("@worker_thread")).not_to be_alive
    expect(subject.instance_variable_get("@timer_thread")).not_to be_alive
  end

  it 'can produce messages' do
    block = lambda do |request|
      data = JSON.parse(request.body)
      events = data.fetch("events")
      events.size == 5
    end

    stub_request(:post, "https://www.featureflipper.com/adapter/events")
      .with(&block)
      .to_return(status: 201)

    5.times { subject.produce(event) }
    subject.deliver
    subject.shutdown
  end
end

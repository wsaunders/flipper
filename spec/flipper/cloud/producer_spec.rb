require 'helper'
require 'flipper/cloud'
require 'flipper/cloud/event'
require 'flipper/cloud/configuration'
require 'flipper/cloud/producer'
require 'flipper/instrumenters/memory'

RSpec.describe Flipper::Cloud::Producer do
  let(:instrumenter) do
    Flipper::Instrumenters::Memory.new
  end

  let(:configuration) do
    attributes = {
      token: "asdf",
      event_capacity: 10,
      event_batch_size: 5,
      instrumenter: instrumenter,
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

  before do
    stub_request(:post, "https://www.featureflipper.com/adapter/events")
  end

  it 'creates thread on produce and kills on shutdown' do
    configuration.event_flush_interval = 0.1

    expect(subject.instance_variable_get("@worker_thread")).to be_nil
    expect(subject.instance_variable_get("@timer_thread")).to be_nil

    subject.produce(event)

    expect(subject.instance_variable_get("@worker_thread")).to be_instance_of(Thread)
    expect(subject.instance_variable_get("@timer_thread")).to be_instance_of(Thread)

    subject.shutdown

    sleep configuration.event_flush_interval * 2

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

  it 'instruments producer submission response errors' do
    stub_request(:post, "https://www.featureflipper.com/adapter/events")
      .to_return(status: 500)
    subject.produce(event)
    subject.shutdown
    submission_event = instrumenter.events.detect do |event|
      event.name == "producer_submission_response_error.flipper"
    end
    expect(submission_event).not_to be_nil
    expect(submission_event.payload[:response]).to be_instance_of(Net::HTTPInternalServerError)
  end

  it 'instruments producer submission exceptions' do
    exception = StandardError.new
    stub_request(:post, "https://www.featureflipper.com/adapter/events")
      .to_raise(exception)
    subject.produce(event)
    subject.shutdown
    submission_event = instrumenter.events.detect do |event|
      event.name == "producer_submission_exception.flipper"
    end
    expect(submission_event).not_to be_nil
    expect(submission_event.payload[:exception]).to be(exception)
  end
end

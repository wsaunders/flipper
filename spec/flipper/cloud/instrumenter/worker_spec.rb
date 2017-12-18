require 'thread'
require 'helper'
require 'flipper/cloud/configuration'
require 'flipper/instrumenters/memory'
require 'flipper/cloud/instrumenter/worker'

RSpec.describe Flipper::Cloud::Instrumenter::Worker do
  let(:instrumenter) { Flipper::Instrumenters::Memory.new }
  let(:event) {
    Flipper::Cloud::Instrumenter::Event.new("feature_operation.flipper", {
      result: true,
      feature_name: :foo,
      operation: :enabled?,
      gate_name: :percentage_of_actors,
      thing: Flipper::Types::Actor.new(Flipper::Actor.new("User;23")),
    })
  }
  let(:queue) { Queue.new }
  let(:client) {
    Class.new do
      attr_reader :requests

      def initialize
        @requests = []
      end

      def post(path, body)
        @requests << [path, body]
      end
    end.new
  }

  it 'can be shutdown' do
    worker = described_class.new(queue, client)
    thread = Thread.new { worker.run }
    expect(thread).to be_alive
    worker.shutdown
    thread.join
    expect(thread).to_not be_alive
    expect(client.requests.size).to be(0)
  end

  it 'raises for unknown event' do
    worker = described_class.new(queue, client)
    thread = Thread.new { worker.run }
    expect(thread).to be_alive
    queue << "nooope"
    expect { thread.join }.to raise_error(RuntimeError)
    expect(thread).to_not be_alive
    expect(client.requests.size).to be(0)
  end

  it 'posts event to client' do
    worker = described_class.new(queue, client)
    thread = Thread.new { worker.run }
    150.times { queue << event }
    worker.shutdown
    thread.join

    expect(client.requests.size).to be(2)

    path, body = client.requests[0]
    hash = JSON.load(body)
    expect(hash["events"].size).to be(100)

    path, body = client.requests[1]
    hash = JSON.load(body)
    expect(hash["events"].size).to be(50)
  end
end

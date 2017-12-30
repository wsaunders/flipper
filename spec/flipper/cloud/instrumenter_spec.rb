require 'helper'
require 'flipper/instrumenters/memory'
require 'flipper/cloud/instrumenter'
require 'flipper/cloud/configuration'

RSpec.describe Flipper::Cloud::Instrumenter do
  let(:instrumenter) { Flipper::Instrumenters::Memory.new }
  let(:event_queue) { Queue.new }
  let(:event_capacity) { 10 }
  let(:event_flush_interval) { 60 }
  let(:configuration) do
    attributes = {
      token: "asdf",
      instrumenter: instrumenter,
      event_queue: event_queue,
      event_capacity: event_capacity,
      event_flush_interval: event_flush_interval,
    }
    Flipper::Cloud::Configuration.new(attributes)
  end
  subject { described_class.new(configuration) }

  describe '#instrument' do
    context 'with block' do
      before do
        @yielded = 0
        @result = subject.instrument(Flipper::Feature::InstrumentationName, bar: "baz") do
          @yielded += 1
          :foo_result
        end
      end

      it 'sends instrument to wrapped instrumenter' do
        expect(instrumenter.events.size).to be(1)
        event = instrumenter.events.first
        expect(event.name).to eq(Flipper::Feature::InstrumentationName)
        expect(event.payload).to eq(bar: "baz")
      end

      it 'returns result of wrapped instrumenter instrument method call' do
        expect(@result).to eq :foo_result
      end

      it 'only yields block once' do
        expect(@yielded).to eq 1
      end

      it 'adds event to event_queue' do
        expect(configuration.event_queue.size).to be(1)
      end
    end

    context 'without block' do
      before do
        @result = subject.instrument(Flipper::Feature::InstrumentationName, bar: "baz")
      end

      it 'sends instrument to wrapped instrumenter' do
        expect(instrumenter.events.size).to be(1)
        event = instrumenter.events.first
        expect(event.name).to eq(Flipper::Feature::InstrumentationName)
        expect(event.payload).to eq(bar: "baz")
      end

      it 'adds event to event_queue' do
        expect(configuration.event_queue.size).to be(1)
      end
    end

    it 'does not allow event_queue size to exceed event_capacity' do
      (event_capacity * 2).times { subject.instrument(:foo) }
      expect(event_queue.size).to be <= event_capacity
    end
  end
end

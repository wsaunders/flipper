require 'helper'
require 'flipper/instrumenters/memory'
require 'flipper/cloud/instrumenter'
require 'flipper/cloud/configuration'

RSpec.describe Flipper::Cloud::Instrumenter do
  let(:instrumenter) { Flipper::Instrumenters::Memory.new }
  let(:configuration) {
    Flipper::Cloud::Configuration.new({
      token: "asdf",
      instrumenter: instrumenter,
      event_queue: Queue.new,
    })
  }
  subject { described_class.new(configuration) }

  describe '#instrument with block' do
    context 'with block' do
      before do
        @yielded = 0
        @result = subject.instrument(:foo, bar: "baz") do
          @yielded += 1
          :foo_result
        end
      end

      it 'sends instrument to wrapped instrumenter' do
        expect(instrumenter.events.size).to be(1)
        event = instrumenter.events.first
        expect(event.name).to eq(:foo)
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
        @result = subject.instrument(:foo, bar: "baz")
      end

      it 'sends instrument to wrapped instrumenter' do
        expect(instrumenter.events.size).to be(1)
        event = instrumenter.events.first
        expect(event.name).to eq(:foo)
        expect(event.payload).to eq(bar: "baz")
      end

      it 'adds event to event_queue' do
        expect(configuration.event_queue.size).to be(1)
      end
    end

    context 'when under capacity' do
      it 'adds event to queue' do
        subject.instrument(:foo)
        expect(configuration.event_queue.size).to be(1)
      end
    end

    context 'when at capacity' do
      before do
        configuration.event_capacity.times do
          subject.instrument(:foo)
        end
      end

      it 'does not add event to queue' do
        subject.instrument(:foo)
        expect(configuration.event_queue.size).to be(configuration.event_capacity)
      end
    end

    context 'when over capacity' do
      before do
        (configuration.event_capacity + 1).times do
          subject.instrument(:foo)
        end
      end

      it 'does not add event to queue' do
        subject.instrument(:foo)
        expect(configuration.event_queue.size).to be(configuration.event_capacity)
      end
    end
  end
end

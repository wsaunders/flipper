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
    })
  }
  subject { described_class.new(configuration) }

  describe '#instrument with block' do
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
  end

  describe '#instrument without block' do
    before do
      @result = subject.instrument(:foo, bar: "baz")
    end

    it 'sends instrument to wrapped instrumenter' do
      expect(instrumenter.events.size).to be(1)
      event = instrumenter.events.first
      expect(event.name).to eq(:foo)
      expect(event.payload).to eq(bar: "baz")
    end
  end
end

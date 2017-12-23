require 'helper'
require 'flipper/event_receivers/memory'

RSpec.describe Flipper::EventReceivers::Memory do
  it 'is enumerable' do
    batches = [Object.new, Object.new, Object.new]
    batches.each { |batch| subject.call(batch) }
    subject.each_with_index do |batch, index|
      expect(batch).to be(batches[index])
    end
    expect(subject.map { |batch| batch }.size).to be(batches.size)
  end

  it 'aliases size to count' do
    subject.call(Object.new)
    expect(subject.size).to be(1)
    expect(subject.size).to eq(subject.count)
  end
end

require 'helper'
require 'flipper/event_receivers/noop'

RSpec.describe Flipper::EventReceivers::Noop do
  it 'responds to call' do
    described_class.call(Object.new)
  end
end

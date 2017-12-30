require File.expand_path('../../example_setup', __FILE__)

require 'flipper/cloud'
require 'flipper/adapters/active_support_cache_store'
require 'active_support/cache'
require 'active_support/cache/memory_store'

token = ENV.fetch("TOKEN") { abort "TOKEN environment variable not set." }
feature_name = ENV.fetch("FEATURE") { "testing" }.to_sym

Flipper.configure do |config|
  config.default do
    Flipper::Cloud.new(token) do |cloud|
      cloud.url = "http://localhost:5000/adapter"
      cloud.debug_output = STDOUT
      cloud.adapter do |adapter|
        Flipper::Adapters::ActiveSupportCacheStore.new(adapter,
          ActiveSupport::Cache::MemoryStore.new, {expires_in: 60.seconds})
      end
      cloud.event_capacity = 10_000
      cloud.event_flush_interval = 5
      cloud.event_batch_size = 1_000
    end
  end
end

actor = Flipper::Actor.new("User;23")

loop do
  begin
    Flipper.enabled?(feature_name, actor)
  rescue

  end

  sleep 0.1
end

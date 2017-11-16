require 'helper'
require 'active_support/cache'
require 'active_support/cache/dalli_store'
require 'flipper/adapters/memory'
require 'flipper/adapters/operation_logger'
require 'flipper/adapters/active_support_cache_store/resilient'
require 'flipper/spec/shared_adapter_specs'

RSpec.describe Flipper::Adapters::ActiveSupportCacheStore::Resilient do
  let(:memory_adapter) do
    Flipper::Adapters::OperationLogger.new(Flipper::Adapters::Memory.new)
  end
  let(:memory_flipper) { Flipper.new(memory_adapter) }
  let(:cache) { ActiveSupport::Cache::DalliStore.new }
  let(:adapter) { described_class.new(memory_adapter, cache, expires_in: 10.seconds) }
  let(:flipper) { Flipper.new(adapter) }

  subject { adapter }

  before do
    cache.clear
  end

  it_should_behave_like 'a flipper adapter'

  describe '#remove' do
    it 'expires feature' do
      feature = flipper[:stats]
      adapter.get(feature)
      adapter.remove(feature)
      expect(cache.read(described_class.key_for(feature.key))).to be(nil)
    end
  end

  describe '#get' do
    it 'does hit wrapped adapter when uncached' do
      feature = flipper[:stats]
      feature.enable
      expect(adapter.get(feature).fetch(:boolean)).to eq("true")
      expect(memory_adapter.count(:get)).to be(1)
      expect(cache.read(described_class.key_for(feature.key))).to_not be(nil)
    end

    it 'does not hit wrapped adapter when cached and fresh' do
      feature = flipper[:stats]
      feature.enable
      expect(adapter.get(feature).fetch(:boolean)).to eq("true")
      entry = cache.read(described_class.key_for(feature.key))

      5.times do
        expect(adapter.get(feature).fetch(:boolean)).to eq("true")
      end
      expect(memory_adapter.count(:get)).to be(1)

      cached_expires_at = cache.read(described_class.key_for(feature.key)).expires_at
      expect(cached_expires_at).to eq(entry.expires_at)
    end

    it 'does hit wrapped adapter when cached but stale' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get(feature)
      cached_value = cache.read(described_class.key_for(feature.key))
      expect(result.fetch(:boolean)).to eq("true")

      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)
      result = adapter.get(feature)
      expect(result.fetch(:boolean)).to eq("true")
      expect(memory_adapter.count(:get)).to be(2)

      new_cached_value = cache.read(described_class.key_for(feature.key))
      expect(new_cached_value.expires_at > cached_value.expires_at).to be(true)
    end

    it 'does return stale data when cached and stale if wrapped adapter errors' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get(feature)
      memory_flipper.disable(:stats)
      memory_adapter.reset

      cached_value = cache.read(described_class.key_for(feature.key))

      # simulate expiration by advancing time to expires_at + 1 second
      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)

      # simulate memory adapter error
      expect(memory_adapter).to receive(:get).and_raise

      result = adapter.get(feature)
      expect(result.fetch(:boolean)).to eq("true") # stale
      expect(memory_adapter.count(:get)).to be(0)

      # show that cache expires at is updated to avoid pounding wrapped
      # adapter when it is failing
      new_cached_value = cache.read(described_class.key_for(feature.key))
      expect(new_cached_value.expires_at > cached_value.expires_at).to be(true)
    end
  end

  describe '#get_multi' do
    it 'does hit wrapped adapter when uncached' do
      feature = flipper[:stats]
      feature.enable

      adapter.get_multi([feature])
      expect(cache.read(described_class.key_for(feature.key))[:boolean]).to eq('true')

      adapter.get_multi([feature])
      adapter.get_multi([feature])
      expect(memory_adapter.count(:get_multi)).to eq(1)
    end

    it 'does not hit wrapped adapter when cached and fresh' do
      feature = flipper[:stats]
      feature.enable
      expect(adapter.get_multi([feature]).fetch(feature.key).fetch(:boolean)).to eq("true")
      entry = cache.read(described_class.key_for(feature.key))

      5.times do
        expect(adapter.get_multi([feature]).fetch(feature.key).fetch(:boolean)).to eq("true")
      end
      expect(memory_adapter.count(:get_multi)).to be(1)

      cached_expires_at = cache.read(described_class.key_for(feature.key)).expires_at
      expect(cached_expires_at).to eq(entry.expires_at)
    end

    it 'does hit wrapped adapter when cached but stale' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get_multi([feature])
      cached_value = cache.read(described_class.key_for(feature.key))
      expect(result.fetch(feature.key).fetch(:boolean)).to eq("true")

      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)
      result = adapter.get_multi([feature])
      expect(result.fetch(feature.key).fetch(:boolean)).to eq("true")
      expect(memory_adapter.count(:get_multi)).to be(2)

      new_cached_value = cache.read(described_class.key_for(feature.key))
      expect(new_cached_value.expires_at > cached_value.expires_at).to be(true)
    end

    it 'does return stale data when cached and stale if wrapped adapter errors' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get_multi([feature])
      memory_flipper.disable(feature.key)
      memory_adapter.reset

      cached_value = cache.read(described_class.key_for(feature.key))

      # simulate expiration by advancing time to expires_at + 1 second
      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)

      # simulate memory adapter error
      expect(memory_adapter).to receive(:get_multi).and_raise

      result = adapter.get_multi([feature])
      expect(result.fetch(feature.key).fetch(:boolean)).to eq("true") # stale
      expect(memory_adapter.count(:get_multi)).to be(0)

      # show that cache expires at is updated to avoid pounding wrapped
      # adapter when it is failing
      new_cached_value = cache.read(described_class.key_for(feature.key))
      expect(new_cached_value.expires_at > cached_value.expires_at).to be(true)
    end
  end

  describe '#get_all' do
    let(:stats) { flipper[:stats] }
    let(:search) { flipper[:search] }

    before do
      stats.enable
      search.add
    end

    it 'warms all features' do
      adapter.get_all
      expect(cache.read(described_class.key_for(stats.key))[:boolean]).to eq('true')
      expect(cache.read(described_class.key_for(search.key))[:boolean]).to be(nil)
      expect(cache.read(described_class::GetAllKey)).to be_within(2).of(Time.now.to_i)
    end

    it 'returns same result when already cached' do
      expect(adapter.get_all).to eq(adapter.get_all)
    end

    it 'only invokes one call to wrapped adapter' do
      5.times { adapter.get_all }
      expect(memory_adapter.count(:get_all)).to eq(1)
    end

    it 'does hit wrapped adapter when uncached' do
      feature = flipper[:stats]
      feature.enable

      adapter.get_all
      expect(cache.read(described_class.key_for(feature.key))[:boolean]).to eq('true')

      adapter.get_all
      adapter.get_all
      expect(memory_adapter.count(:get_all)).to eq(1)
    end

    it 'does not hit wrapped adapter when cached and fresh' do
      feature = flipper[:stats]
      feature.enable
      expect(adapter.get_all.fetch(feature.key).fetch(:boolean)).to eq("true")
      entry = cache.read(described_class.key_for(feature.key))

      5.times do
        expect(adapter.get_all.fetch(feature.key).fetch(:boolean)).to eq("true")
      end
      expect(memory_adapter.count(:get_all)).to be(1)

      cached_expires_at = cache.read(described_class.key_for(feature.key)).expires_at
      expect(cached_expires_at).to eq(entry.expires_at)
    end

    it 'does hit wrapped adapter when cached but stale' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get_all
      cached_value = cache.read(described_class.key_for(feature.key))
      expect(result.fetch(feature.key).fetch(:boolean)).to eq("true")

      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)
      result = adapter.get_all
      expect(result.fetch(feature.key).fetch(:boolean)).to eq("true")

      # first get all
      expect(memory_adapter.count(:get_all)).to be(1)

      # after first get_all, get_all uses get_multi to optimize cache usage and
      # avoid calling get_all on wrapped adapter even when cached
      expect(memory_adapter.count(:get_multi)).to be(1)

      new_cached_value = cache.read(described_class.key_for(feature.key))
      expect(new_cached_value.expires_at > cached_value.expires_at).to be(true)
    end

    it 'does return stale data when cached and stale and get_all key set if wrapped adapter errors' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get_all
      memory_flipper.disable(feature.key)
      memory_adapter.reset

      cached_value = cache.read(described_class.key_for(feature.key))

      # simulate expiration by advancing time to expires_at + 1 second
      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)

      # simulate memory adapter error
      expect(memory_adapter).to receive(:get_multi).and_raise

      result = adapter.get_all
      expect(result.fetch(feature.key).fetch(:boolean)).to eq("true") # stale
      expect(memory_adapter.count(:get_multi)).to be(0)

      # show that cache expires_at is updated to avoid pounding wrapped
      # adapter when it is failing
      new_cached_value = cache.read(described_class.key_for(feature.key))
      expect(new_cached_value.expires_at > cached_value.expires_at).to be(true)
    end

    it 'does return stale data when cached and stale and get_all key unset if wrapped adapter errors' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get_all
      memory_flipper.disable(feature.key)
      memory_adapter.reset

      cached_value = cache.read(described_class.key_for(feature.key))

      # simulate expiration by advancing time to expires_at + 1 second
      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)

      # simulate memory adapter error
      expect(memory_adapter).to receive(:get_all).and_raise

      # remove get_all key so another full get_all is requested from wrapped adapter
      cache.delete(described_class::GetAllKey)

      result = adapter.get_all
      expect(result.fetch(feature.key).fetch(:boolean)).to eq("true") # stale
      expect(memory_adapter.count(:get_multi)).to be(0)

      # show that cache expires_at is updated to avoid pounding wrapped
      # adapter when it is failing
      new_cached_value = cache.read(described_class.key_for(feature.key))
      expect(new_cached_value.expires_at > cached_value.expires_at).to be(true)
    end

    it 'raises when get_all key unset if feature keys not cached and wrapped adapter errors' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get_all
      memory_flipper.disable(feature.key)
      memory_adapter.reset

      cached_value = cache.read(described_class.key_for(feature.key))

      # simulate expiration by advancing time to expires_at + 1 second
      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)

      # simulate memory adapter error
      expect(memory_adapter).to receive(:get_all).and_raise

      # remove get_all key so another full get_all is requested from wrapped adapter
      cache.delete(described_class::GetAllKey)

      # remove features key
      cache.delete(described_class::FeaturesKey)

      expect { adapter.get_all }.to raise_error(RuntimeError)
    end

    it 'raises when get_all key unset if not cached and wrapped adapter errors' do
      feature = flipper[:stats]
      feature.enable

      result = adapter.get_all
      memory_flipper.disable(feature.key)
      memory_adapter.reset

      cached_value = cache.read(described_class.key_for(feature.key))

      # simulate expiration by advancing time to expires_at + 1 second
      allow(Time).to receive(:now).and_return(cached_value.expires_at + 1)

      # simulate memory adapter error
      expect(memory_adapter).to receive(:get_all).and_raise

      # remove get_all key so another full get_all is requested from wrapped adapter
      cache.delete(described_class::GetAllKey)

      # remove feature from cache to simulate one feature not being cached
      cache.delete(described_class.key_for(feature.key))

      expect { adapter.get_all }.to raise_error(RuntimeError)
    end
  end

  describe '#name' do
    it 'is active_support_cache_store' do
      expect(subject.name).to be(:active_support_cache_store)
    end
  end
end

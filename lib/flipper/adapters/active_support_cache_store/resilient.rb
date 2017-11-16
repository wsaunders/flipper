require "delegate"

module Flipper
  module Adapters
    class ActiveSupportCacheStore
      class Resilient
        include ::Flipper::Adapter

        Version = 'v1'.freeze
        Namespace = "flipper/#{Version}".freeze
        FeaturesKey = "#{Namespace}/features".freeze
        GetAllKey = "#{Namespace}/get_all".freeze

        # Private
        def self.key_for(key)
          "#{Namespace}/feature/#{key}"
        end

        class GateValuesEntry
          extend Forwardable

          attr_reader :key, :gate_values_hash, :expires_at

          def_delegators :@gate_values_hash, :[], :fetch

          def initialize(key, gate_values_hash, expires_at: nil)
            @key = key
            @gate_values_hash = gate_values_hash
            @expires_at = expires_at
          end

          def expired?
            !fresh?
          end

          def fresh?
            Time.now.to_i < @expires_at
          end
        end

        # Internal
        attr_reader :cache

        # Public: The name of the adapter.
        attr_reader :name

        # Public
        def initialize(adapter, cache, expires_in: nil)
          @adapter = adapter
          @name = :active_support_cache_store
          @cache = cache
          @expires_in = expires_in
          @ttl_options = {expires_in: expires_in}
          @no_ttl_options = {expires_in: nil}
        end

        # Public
        def features
          read_feature_keys
        end

        # Public
        def add(feature)
          result = @adapter.add(feature)
          @cache.delete(FeaturesKey)
          result
        end

        def remove(feature)
          result = @adapter.remove(feature)
          @cache.delete(FeaturesKey)
          @cache.delete(key_for(feature.key))
          result
        end

        def clear(feature)
          result = @adapter.clear(feature)
          @cache.delete(key_for(feature.key))
          result
        end

        def get(feature)
          key = key_for(feature.key)
          entry = @cache.fetch(key, @no_ttl_options) do
            build_entry key, @adapter.get(feature)
          end

          return entry.gate_values_hash if entry.fresh?

          gate_values_hash = begin
            @adapter.get(feature)
          rescue
            entry.gate_values_hash
          end

          entry = build_entry(key, gate_values_hash)
          write_entry(entry)
          entry.gate_values_hash
        end

        def get_multi(features)
          read_many_features(features)
        end

        def get_all
          if @cache.write(GetAllKey, Time.now.to_i, @ttl_options.merge(unless_exist: true))
            begin
              response = @adapter.get_all
              response.each do |feature_key, value|
                key = key_for(feature_key)
                entry = build_entry(key, value)
                write_entry(entry)
              end
              @cache.write(FeaturesKey, response.keys.to_set, @ttl_options)
              response
            rescue
              if feature_keys = @cache.read(FeaturesKey)
                # we have feature keys, do we have all features
                features = feature_keys.map { |key| Flipper::Feature.new(key, self) }
                cache_keys = features.map { |feature| key_for(feature.key) }
                cache_result = @cache.read_multi(*cache_keys)

                uncached_features = features.select { |feature|
                  cache_result[key_for(feature.key)].nil?
                }

                if uncached_features.empty?
                  cache_result.each do |key, value|
                    write_entry build_entry(key, value.gate_values_hash)
                  end
                  result = {}
                  features.each do |feature|
                    key = key_for(feature.key)
                    result[feature.key] = cache_result[key].gate_values_hash
                  end
                  result
                else
                  raise
                end
              else
                raise
              end
            end
          else
            features = read_feature_keys.map { |key| Flipper::Feature.new(key, self) }
            read_many_features(features)
          end
        end

        def enable(feature, gate, thing)
          result = @adapter.enable(feature, gate, thing)
          @cache.delete(key_for(feature.key))
          result
        end

        def disable(feature, gate, thing)
          result = @adapter.disable(feature, gate, thing)
          @cache.delete(key_for(feature.key))
          result
        end

        private

        def key_for(key)
          self.class.key_for(key)
        end

        def build_entry(key, gate_values_hash)
          GateValuesEntry.new(key, gate_values_hash, expires_at: Time.now.to_f + @expires_in)
        end

        def write_entry(entry)
          @cache.write(entry.key, entry, @no_ttl_options)
        end

        # Internal: Returns an array of the known feature keys.
        def read_feature_keys
          @cache.fetch(FeaturesKey, @ttl_options) { @adapter.features }
        end

        # Internal: Given an array of features, attempts to read through cache in
        # as few network calls as possible.
        def read_many_features(features)
          keys = features.map { |feature| key_for(feature.key) }
          cache_result = @cache.read_multi(*keys)
          features_to_cache = features.select { |feature|
            entry = cache_result[key_for(feature)]
            entry.nil? || entry.expired?
          }

          if features_to_cache.any?
            entries = []
            begin
              response = @adapter.get_multi(features_to_cache)
              response.each do |feature_key, gate_values_hash|
                entries << build_entry(key_for(feature_key), gate_values_hash)
              end
            rescue
              features_to_cache.each do |feature|
                key = key_for(feature.key)
                entry = cache_result[key]
                gate_values_hash = entry ? entry.gate_values_hash : default_config
                entries << build_entry(key, gate_values_hash)
              end
            end

            entries.each do |entry|
              write_entry(entry)
              cache_result[entry.key] = entry
            end
          end

          result = {}
          features.each do |feature|
            key = key_for(feature.key)
            result[feature.key] = cache_result[key].gate_values_hash
          end
          result
        end
      end
    end
  end
end

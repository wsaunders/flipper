require 'net/http'
require 'json'
require 'set'
require 'flipper'
require 'flipper/adapters/http/error'
require 'flipper/adapters/http/client'

module Flipper
  module Adapters
    class Http
      include Flipper::Adapter

      attr_reader :name, :client, :url

      def initialize(options = {})
        @url = options.fetch(:url)
        @client = options.fetch(:client) do
          client_options = {
            headers: options[:headers],
            basic_auth_username: options[:basic_auth_username],
            basic_auth_password: options[:basic_auth_password],
            read_timeout: options[:read_timeout],
            open_timeout: options[:open_timeout],
            debug_output: options[:debug_output],
          }
          Client.new(client_options)
        end
        @name = :http
      end

      def get(feature)
        url = url_for("/features/#{feature.key}")
        response = @client.get(url)
        if response.is_a?(Net::HTTPOK)
          parsed_response = JSON.parse(response.body)
          result_for_feature(feature, parsed_response.fetch('gates'))
        elsif response.is_a?(Net::HTTPNotFound)
          default_config
        else
          raise Error, response
        end
      end

      def add(feature)
        url = url_for("/features")
        body = JSON.generate(name: feature.key)
        response = @client.post(url, body: body)
        response.is_a?(Net::HTTPOK)
      end

      def get_multi(features)
        csv_keys = features.map(&:key).join(',')
        url = url_for("/features?keys=#{csv_keys}")
        response = @client.get(url)
        raise Error, response unless response.is_a?(Net::HTTPOK)

        parsed_response = JSON.parse(response.body)
        parsed_features = parsed_response.fetch('features')
        gates_by_key = parsed_features.each_with_object({}) do |parsed_feature, hash|
          hash[parsed_feature['key']] = parsed_feature['gates']
          hash
        end

        result = {}
        features.each do |feature|
          result[feature.key] = result_for_feature(feature, gates_by_key[feature.key])
        end
        result
      end

      def get_all
        url = url_for("/features")
        response = @client.get(url)
        raise Error, response unless response.is_a?(Net::HTTPOK)

        parsed_response = JSON.parse(response.body)
        parsed_features = parsed_response.fetch('features')
        gates_by_key = parsed_features.each_with_object({}) do |parsed_feature, hash|
          hash[parsed_feature['key']] = parsed_feature['gates']
          hash
        end

        result = {}
        gates_by_key.keys.each do |key|
          feature = Feature.new(key, self)
          result[feature.key] = result_for_feature(feature, gates_by_key[feature.key])
        end
        result
      end

      def features
        url = url_for("/features")
        response = @client.get(url)
        raise Error, response unless response.is_a?(Net::HTTPOK)

        parsed_response = JSON.parse(response.body)
        parsed_response['features'].map { |feature| feature['key'] }.to_set
      end

      def remove(feature)
        url = url_for("/features/#{feature.key}")
        response = @client.delete(url)
        response.is_a?(Net::HTTPNoContent)
      end

      def enable(feature, gate, thing)
        body = request_body_for_gate(gate, thing.value.to_s)
        query_string = gate.key == :groups ? "?allow_unregistered_groups=true" : ""
        url = url_for("/features/#{feature.key}/#{gate.key}#{query_string}")
        response = @client.post(url, body: body)
        response.is_a?(Net::HTTPOK)
      end

      def disable(feature, gate, thing)
        body = request_body_for_gate(gate, thing.value.to_s)
        query_string = gate.key == :groups ? "?allow_unregistered_groups=true" : ""
        url = url_for("/features/#{feature.key}/#{gate.key}#{query_string}")
        response =
          case gate.key
          when :percentage_of_actors, :percentage_of_time
            @client.post(url, body: body)
          else
            @client.delete(url, body: body)
          end
        response.is_a?(Net::HTTPOK)
      end

      def clear(feature)
        url = url_for("/features/#{feature.key}/clear")
        response = @client.delete(url)
        response.is_a?(Net::HTTPNoContent)
      end

      private

      def url_for(path)
        Flipper::Util.url_for(@url, path)
      end

      def request_body_for_gate(gate, value)
        data = case gate.key
               when :boolean
                 {}
               when :groups
                 { name: value }
               when :actors
                 { flipper_id: value }
               when :percentage_of_actors, :percentage_of_time
                 { percentage: value }
               else
                 raise "#{gate.key} is not a valid flipper gate key"
               end
        JSON.generate(data)
      end

      def result_for_feature(feature, api_gates)
        api_gates ||= []
        result = default_config

        feature.gates.each do |gate|
          api_gate = api_gates.detect { |ag| ag['key'] == gate.key.to_s }
          result[gate.key] = value_for_gate(gate, api_gate) if api_gate
        end

        result
      end

      def value_for_gate(gate, api_gate)
        value = api_gate['value']
        case gate.data_type
        when :boolean, :integer
          value ? value.to_s : value
        when :set
          value ? value.to_set : Set.new
        else
          unsupported_data_type(gate.data_type)
        end
      end

      def unsupported_data_type(data_type)
        raise "#{data_type} is not supported by this adapter"
      end
    end
  end
end

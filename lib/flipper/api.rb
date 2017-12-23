require 'rack'
require 'flipper'
require 'flipper/event_receivers/noop'
require 'flipper/middleware/setup_env'
require 'flipper/middleware/memoizer'
require 'flipper/api/middleware'

module Flipper
  module Api
    CONTENT_TYPE = 'application/json'.freeze

    def self.app(flipper = nil, options = {})
      env_key = options.fetch(:env_key, 'flipper')
      event_receiver = options.fetch(:event_receiver, EventReceivers::Noop)
      app = ->(_) { [404, { 'Content-Type'.freeze => CONTENT_TYPE }, ['{}'.freeze]] }
      builder = Rack::Builder.new
      yield builder if block_given?
      builder.use Flipper::Middleware::SetupEnv, flipper, env_key: env_key
      builder.use Flipper::Middleware::Memoizer, env_key: env_key
      builder.use Flipper::Api::Middleware, env_key: env_key, event_receiver: event_receiver
      builder.run app
      klass = self
      builder.define_singleton_method(:inspect) { klass.inspect } # pretty rake routes output
      builder
    end
  end
end

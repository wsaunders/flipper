module Flipper
  module Instrumenters
    class Noop
      def self.instrument(_name, payload = {})
        yield payload if block_given?
      end

      def self.subscribe(*args, &block)
      end
    end
  end
end

module Flipper
  module Instrumenters
    class Noop
      def self.instrument(_name, payload = {})
        yield payload if block_given?
      end

      def self.subscribe(*_args, &_block)
      end
    end
  end
end

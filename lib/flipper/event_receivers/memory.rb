module Flipper
  module EventReceivers
    class Memory
      extend Forwardable
      include Enumerable

      def initialize
        @batches = []
      end

      def call(batch)
        @batches << batch
      end

      def each(&block)
        @batches.each(&block)
      end

      alias_method :size, :count

      def_delegator :@batches, :clear
    end
  end
end

module Flipper
  module EventReceivers
    class Memory
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
    end
  end
end

module Flipper
  module EventReceivers
    module Noop
      def self.call(_request)
        # Minimal event receiver. LOL.
      end
    end
  end
end

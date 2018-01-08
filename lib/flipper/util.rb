module Flipper
  module Util
    module_function

    def timestamp(now = Time.now)
      (now.to_f * 1_000).floor
    end
  end
end

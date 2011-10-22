
module EM::Rserve
  module Protocol
    # Simple Request structure holding a references to a callback and an errback
    Request = Struct.new(:callback_blk, :errback_blk) do
      # sets the async callback with a block argument
      def callback(&blk)
        self.callback_blk = blk
      end

      # sets the async errback with a block argument
      def errback(&blk)
        self.errback_blk = blk
      end

      # calls the errback 
      def error(val)
        errback_blk.call(val) if errback_blk
      end

      # calls the callback
      def success(val)
        callback_blk.call(val) if callback_blk
      end
    end
  end
end

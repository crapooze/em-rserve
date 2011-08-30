
module EM::Rserve
  module Protocol
    Request = Struct.new(:callback_blk, :errback_blk) do
      def callback(&blk)
        self.callback_blk = blk
      end

      def errback(&blk)
        self.errback_blk = blk
      end

      def error(val)
        errback_blk.call(val) if errback_blk
      end

      def success(val)
        callback_blk.call(val) if callback_blk
      end
    end
  end
end

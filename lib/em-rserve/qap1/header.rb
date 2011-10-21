
require 'em-rserve/qap1/constants'

module EM::Rserve
  module QAP1
    Header = Struct.new(:command, :length, :offset, :length2) do

      def self.from_bin(dat)
        raise unless dat.size == 16
        self.new(* dat.unpack('VVVV'))
      end

      def message_length
        length | length2 << 32 
      end

      def body?
        message_length > 0
      end

      def to_bin
        to_a.pack('VVVV')
      end

      def response?
        command & Constants::CMD_RESP > 0
      end

      def ok?
        command & Constants::RESP_OK > 0
      end

      def error?
        ((command & Constants::RESP_ERR) & ~Constants::RESP_OK) > 0
      end

      def error
        ((command & ~Constants::RESP_ERR) >> 24) & 0xff
      end

      #     -> self.for_message
      #     -> prepare_message
    end
  end
end

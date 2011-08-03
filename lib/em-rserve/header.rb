
require 'em-rserve/qap1'

module EM::Rserve
  Header = Struct.new(:command, :length, :offset, :length2) do
    include QAP1

    def self.from_bin(dat)
      raise unless dat.size == 16
      self.new(* dat.unpack('VVVV'))
    end

    def message_length
      length #TODO: use length2
    end

    def body?
      message_length > 0
    end

    def to_bin
      to_a.pack('VVVV')
    end

    def response?
      command & CMD_RESP > 0
    end

    def ok?
      command & RESP_OK > 0
    end

    def error?
      command & RESP_ERR > 0
    end

    def error
      ((command & ~RESP_ERR) >> 24) & 0xff
    end

    #     -> self.for_message
    #     -> prepare_message
  end
end


require 'em-rserve/qap1'

module EM::Rserve
  module Rpack
    include QAP1

    def parameter_head(type, len)
      (type & 0x000000ff) | ((len << 8) & 0xffffff00)
    end

    def pack_parameter(type, len, val, rule)
      [parameter_head(type, len), val].flatten.pack('V'+rule)
    end

    def encode_parameter(param, type=nil)
      type ||= param
      case param
      when Integer, :int
        encode_int param
      when :char
        encode_char param
      when Float, :double
        encode_double param
      when String, :string
        encode_string param
      when :bytestream
        encode_bytestream param
        #XXX Array and rest
      end
    end

    def encode_int(val)
      pack_parameter(DT_INT, 4, val, 'V')
    end

    def encode_char(val)
      pack_parameter(DT_CHAR, 1, val, 'C')
    end

    def encode_double(val)
      pack_parameter(DT_DOUBLE, 8, val, 'D')
    end

    def encode_string(val, len=nil, has_null=false)
      if has_null
        len ||= val.length
        pack_parameter(DT_STRING, len, val, 'a*')
      else
        len ||= val.length + 1
        pack_parameter(DT_STRING, len, [val, 0], 'a*C')
      end
    end

    def encode_bytestream(val, len=nil)
      len ||= val.length
      pack_parameter(DT_BYTESTREAM, len, val, 'a*')
    end

    def encode_large(val, len=nil)
    end

    def encode_sexp(val, len=nil)
    end

    def encode_array(val, len=nil)
    end

    def head_parameter(head)
      type = head & 0x000000ff 
      len  = (head & 0xffffff00) >> 8
      [type, len]
    end

    def decode_sexp(dat)
      Sexp.parse(dat)
    end

    def decode_int(dat)
      dat.unpack('i').first
    end

    def decode_bytestream(dat)
      dat
    end

    def decode_parameter(type, dat, len=nil)
      case type
      when DT_SEXP
        decode_sexp dat
      when DT_INT
        decode_int dat
      when DT_BYTESTREAM
        decode_bytestream dat
      else 
        p "missing decode: #{type}"
      end
    end

    def decode_parameters(buffer)
      params = []
      until buffer.empty? do
        head, buffer = buffer.unpack('Va*')
        type, len = head_parameter(head)
        if buffer.size < len
          raise RuntimeError, "cannot decode #{buffer} (not enough bytes)"
        end
        param_data = buffer.slice(0, len)
        buffer = buffer.slice(len .. -1)
        params << decode_parameter(type, param_data, len)
      end
      params
    end
  end
end

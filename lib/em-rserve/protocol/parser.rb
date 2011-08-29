
require 'em-rserve/protocol/id'
require 'em-rserve/qap1/header'
require 'em-rserve/qap1/message'
require 'em-rserve/sexp'

module EM::Rserve
  class Parser
    attr_reader :handler, :buffer

    def initialize(handler)
      @handler = handler
      @buffer  = ''
    end

    def replace(other)
      @buffer.replace(other.buffer)
      self
    end

    def << data
      buffer << data if data
      parse_loop!
    end

    def parse_loop!
      catch :stop do
        loop do
          parse!
        end
      end
    end

    # should overload this method and throw :stop when more data is needed or any other
    # reason to stop parsing
    def parse!
      raise NotImplementedError, "this class is intended to be a top class, not a useful parser"
    end
  end

  # This parser is useful only at the beginning.
  # Instead of carrying its dynamic all the time (e.g., keeping a state).
  # We pop-it out as another parser.
  class IDParser < Parser
    def parse!
      if buffer.size >= 4
        dat = buffer.slice(0, 4)
        @buffer = buffer.slice(4 .. -1)
        handler.receive_id(ID.new(dat))
      else
        throw :stop
      end
    end
  end

  # This message parser will parse qap1 headers and associated qap1 data.
  class MessageParser < Parser
    def initialize(handler)
      super(handler)
      @header  = nil
    end

    def parse!
      if @header
        #XXX here we have a header with the size of data
        #to expect, out approach is to delay the message
        #until we have all the data, not well suited for
        #streams but for all other messages this is the
        #good way of doing it
        expected_length = @header.message_length
        if expected_length > 0 and buffer.size >= expected_length
          dat = buffer.slice(0, expected_length)
          @buffer = buffer.slice(expected_length .. -1)
          message = Message.from_bin dat
          handler.receive_message message
          @header = nil
        else
          throw :stop
        end
      elsif buffer.size >= 16
        dat = buffer.slice(0, 16)
        @buffer = buffer.slice(16 .. -1)
        @header = Header.from_bin dat
        handler.receive_message_header @header
        @header = nil unless @header.body?
      else
        throw :stop
      end
    end
  end
end

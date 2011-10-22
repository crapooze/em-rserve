
require 'em-rserve/protocol/id'
require 'em-rserve/qap1/header'
require 'em-rserve/qap1/message'
require 'em-rserve/r/sexp'

module EM::Rserve
  module Protocol
    # Top class for parsers.
    class Parser
      # A handler is an object which will receive method calls from parsers on
      # specific events.
      attr_reader :handler

      # A buffer holding data.
      attr_reader :buffer

      # Initializes a new Parser and stores the handler.
      def initialize(handler)
        @handler = handler
        @buffer  = ''
      end

      # Replaces current buffer with other's parser's buffer.
      # This is useful when handing-over from one type of parsing to another.
      def replace(other)
        @buffer.replace(other.buffer)
        self
      end

      # Input some data to the parser. As there is new data, will start a
      # parsing loop by calling parse_loop!
      def << data
        buffer << data if data
        parse_loop!
      end

      # Infinitely calls the parse! method (to override in subclasses of parsers).
      # To get out of the loop (e.g., when we realize that there is not enough
      # data in the buffer to complete a message), one must throw :stop .
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
    #
    # This parser's handler must respond_to :receive_id
    class IDParser < Parser
      def parse!
        if buffer.size >= 4
          dat = buffer.slice(0, 4)
          @buffer = buffer.slice(4 .. -1)
          handler.receive_id(Protocol::ID.new(dat))
        else
          throw :stop
        end
      end
    end

    # This message parser will parse qap1 headers and associated qap1 data.
    #
    # This parser's handler must respond_to :receive_message and :receive_message_header
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
            message = QAP1::Message.from_bin dat
            handler.receive_message message
            @header = nil
          else
            throw :stop
          end
        elsif buffer.size >= 16
          dat = buffer.slice(0, 16)
          @buffer = buffer.slice(16 .. -1)
          @header = QAP1::Header.from_bin dat
          handler.receive_message_header @header
          @header = nil unless @header.body?
        else
          throw :stop
        end
      end
    end
  end
end


require "em-rserve/protocol/parser"
require "em-rserve/protocol/request"

module EM::Rserve
  module Protocol
    module Connector 
      def self.included(obj)
        obj.extend ClassMethods
      end

      module ClassMethods
        # Starts a new TCP connection to the server/port parameters
        def start(server='127.0.0.1', port=6311)
          EM.connect(server, port, self)
        end
      end

      extend ClassMethods

      # FIFO for pending requests.
      #
      # RServe protocol implements a synchronous request/response scheme over a
      # single TCP stream. Thus we can hold contexts in a FIFO array of requests
      # to the same server 
      attr_accessor :request_queue

      # Implements EM::Connection post_init hook:
      # - sets the parser to parse IDs
      # - create a request_queue
      def post_init
        super
        #type of parser carries the state, no need to carry it internally and do
        #zillions of state check
        @parser = nil
        replace_parser! IDParser
        @request_queue = []
      end

      # Creates and appends a new request to the request_queue
      # If a block is given, it will be called and the new request will be
      # passed as argument.  
      # Also returns the newly created request.
      #
      # r = connector.request
      # r.success{ p 'good' }
      #
      # connector.request do |r|
      #   r.success{p 'good'}
      # end
      def request
        r = Request.new
        yield r if block_given?
        request_queue << r
        r
      end

      # Replaces current Parser by a new Parser.
      # The klass parameter gives the class to instanciate.
      # Instanciation of the new parser will receive self as only parameter.
      # If the hold parser holds data in its buffer, we may lose this data, hence
      # we call Parser#replace to correctly hand-over the parsing.
      # Note that this complication comes from the RServe protocol which has an
      # initialization phase.
      # Rather than holding the state and testing whether the connection is
      # initialized or not each time we receive a byte, once the initialization
      # phase is done, we just change the parser.
      def replace_parser!(klass)
        new_parser = klass.new(self)
        if @parser
          new_parser.replace(@parser)
        end
        @parser = new_parser
      end

      # Implements EM::Connection receive_data hook, just forwarding to the parser.
      def receive_data(dat)
        @parser << dat
      end

      # Implements IDParser's receive_id callback.
      def receive_id(id)
        # on last line, the messaging can start
        if id.last_one?
          replace_parser! MessageParser
          EM.next_tick do
            ready
          end
          throw :stop
        end
      end

      # HOOKS TO OVERRIDE, PLEASE CALL SUPER

      # This method gets called whenever the connection is started and initialized.
      # By default, it does nothing, you don't need to call super when
      # overriding this method.
      def ready
      end

      # Implements MessageParser's callback.
      # This method gets called whenever the server start answering with a
      # message header.  
      # If you override this method, call super first.
      def receive_message_header(head)
        if head.error?
          receive_error_message_header(head)
        elsif head.ok?
          receive_success_message_header(head)
        else
          raise RuntimeError, "nor OK, nor error message #{head}"
        end
      end

      # This method gets called by receive_message_header if the header is an
      # error.  It dequeues the request_queue FIFO and calls its error method
      # with the header as only parameter.
      # If you override this method, call super first.
      def receive_error_message_header(head)
        request_queue.shift.error(head)
      end

      # This method gets called by receive_message_header if the header is an error.
      # If the header tells us there is no more data to answer this request
      # (i.e., there will be no body data), dequeues the request_queue FIFO and
      # calls the success method with "nil" as only parameter.
      # If you override this method, call super first.
      def receive_success_message_header(head)
        request_queue.shift.success(nil) unless head.body?
      end

      # Implements MessageParser's callback.
      # This methods gets called whenever a message was completely received.
      # Dequeues the request_queue FIFO and calls the success method with the
      # message as only parameter.
      # If you override this method, call super first.
      def receive_message(msg)
        request_queue.shift.success(msg)
      end
    end
  end
end

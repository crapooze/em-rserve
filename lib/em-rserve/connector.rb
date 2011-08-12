
require "em-rserve/parser"
require "em-rserve/request"

module EM::Rserve
  module Connector 
    def self.included(obj)
      obj.extend ClassMethods
    end

    module ClassMethods
      def start(server='127.0.0.1', port=6311)
        EM.connect(server, port, self)
      end
    end

    extend ClassMethods

    attr_accessor :request_queue

    def post_init
      super
      #type of parser carries the state, no need to carry it internally and do
      #zillions of state check
      replace_parser! IDParser
      @request_queue = []
    end

    def request
      r = Request.new
      yield r if block_given?
      request_queue << r
      r
    end

    def replace_parser!(klass)
      new_parser = klass.new(self)
      if @parser
        new_parser.replace(@parser)
      end
      @parser = new_parser
    end

    def receive_data(dat)
      @parser << dat
    end

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

    def ready
    end

    def receive_message_header(head)
      if head.error?
        receive_error_message_header(head)
      elsif head.ok?
        receive_success_message_header(head)
      else
        raise RuntimeError, "nor OK, nor error message #{head}"
      end
    end

    def receive_error_message_header(head)
      request_queue.shift.error(head)
    end

    def receive_success_message_header(head)
      request_queue.shift.success(nil) unless head.body?
    end

    def receive_message(msg)
      request_queue.shift.success(msg)
    end
  end
end

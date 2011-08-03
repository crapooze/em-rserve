
require "em-rserve/parser"

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

    def post_init
      super
      #type of parser carries the state, no need to carry it internally and do
      #zillions of state check
      @parser = IDParser.new(self) 
    end

    def receive_data(dat)
      @parser << dat
    end

    def receive_id(id)
      # on last line, the messaging can start
      if id.last_one?
        @parser = MessageParser.new(self).replace(@parser)
        EM.next_tick do
          ready
        end
        throw :stop
      end
    end

    # HOOKS TO OVERRIDE

    def ready
    end

    def receive_message_header(qap1)
    end

    def receive_message(msg)
    end
  end
end

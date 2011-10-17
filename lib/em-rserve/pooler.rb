
require "em-rserve/fibered_connection"

module EM::Rserve
  class Pooler
    class << self
      def r(klass=FiberedConnection)
        Fiber.new do
          begin
            conn = klass.start 
            yield conn
          ensure
            conn.close_connection
          end
        end.resume
      end
    end

    attr_reader :connections, :size, :connection_class
    def initialize(size=10, klass=FiberedConnection)
      @connections = []
      @size = size
      @connection_class = klass
      fill size
    end

    def empty?
      connections.empty?
    end

    def full?
      connections.size >= size
    end

    def connection
      #XXX duplicated code from Pooler.r to avoid proc-ing the blk
      Fiber.new do
        yield connection_class.start
      end.resume
    end

    def r
      conn = connections.shift
      if conn
        Fiber.new do
          begin
            conn.fiber = Fiber.current
            yield conn
          ensure
            conn.close_connection
          end
          fill 1 unless full?
        end.resume
      else
        fill size
        connection do |conn| 
          begin
            yield conn
          ensure
            conn.close_connection
          end
        end
      end
    end

    def preconnect!
      connection do |conn|
        conn.fiber = nil
        connections << conn
      end
    end

    def fill(n=size)
      n.times{preconnect!}
    end
  end
end

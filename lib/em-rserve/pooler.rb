
require "em-rserve/fibered_connection"
require "em-rserve/backend"

module EM::Rserve
  # A Pooler is a pool of already ready FiberedConnections as new RServe
  # connections are requested, new fibers/connections are added.
  # There is currently no limitation on the maximum number of establish
  # connections, but just a limit on the minimum pre-established connections
  class Pooler
    class << self
      # Immediately creates and yields a new connection of class klass.
      # Shorthand method to create one connection wrapped in a Fiber.
      def r(klass=FiberedConnection, backend=DefaultBackend.new)
        Fiber.new do
          begin
            server = backend.next
            conn = klass.start(Fiber.current, server.host, server.port)
            yield conn
          ensure
            conn.close_connection
          end
        end.resume
      end
    end

    # An array of pending connections
    attr_reader :connections
    # The minimum number of connections to maintain
    attr_reader :size
    # The klass to use when instanciating new connections
    attr_reader :connection_class
    # The backend, which says on which host/port to connect to
    attr_reader :backend

    # Initializes and pre-establish size connections of class klass
    def initialize(size=10, klass=FiberedConnection, backend=DefaultBackend.new)
      @connections = []
      @size = size
      @connection_class = klass
      @backend = backend
      fill size
    end

    # True if there are no connections left in the pool
    def empty?
      connections.empty?
    end

    # True if there are at least size connections in the pool
    def full?
      connections.size >= size
    end

    # Creates and yields a new connection in a Fiber
    def connection
      #XXX duplicated code from Pooler.r to avoid proc-ing the blk
      Fiber.new do
        server = backend.next
        yield connection_class.start(Fiber.current, server.host, server.port)
      end.resume
    end

    # Pick and yield a new connection from the connections pool.
    # If the pool, yield a new connection.
    #
    # This method also ensure that the TCP connection is closed once the work
    # is finished.
    #
    # It also re-establish new connections, trying to maintain the pool filled.
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

    # Preconnect a connection, once the connection is ready, it is added to the
    # connections pool.
    def preconnect!
      connection do |conn|
        conn.fiber = nil
        connections << conn
      end
    end

    # Shorthand to preconnect n connections in parallel.
    def fill(n=size)
      n.times{preconnect!}
    end
  end
end

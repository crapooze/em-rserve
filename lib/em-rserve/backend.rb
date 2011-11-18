
module EM::Rserve
  # A Backend is a way to specify connection parameters.
  # The Pooler rely on a Backend to feed him the list of places to connect.
  # A Backend must respond_to :next, which returns a server.
  class Backend
    include Enumerable

    # A Server just holds an host and a port.
    # It respond to :server answering self. The reason for this is to have
    Server = Struct.new(:host, :port) do
      def ==(other)
        (other.host == self.host) and (other.port == self.port) 
      end

      # Returns self. 
      #
      # The reason for this method is to unify an interface between Server and
      # Backend By doing so, a Backend can have other backends as "servers".
      def server
        self
      end
    end

    def initialize
      yield self if block_given?
    end

    # Interface method to override.
    # Should returns a Server or a look-alike.
    def next
      raise NotImplementedError, "you should use subclasses of Backend"
    end

    # Just call next. 
    #
    # This method is not an alias to survive subclassing.
    #
    # The reason for this method is to unify an interface between Server and
    # Backend By doing so, a Backend can have other backends as "servers".
    def server
      self.next
    end
  end

  # The default backend: an RServe running on localhost and default port (6311)
  class DefaultBackend < Backend
    def initialize
      super
      @server = Server.new('127.0.0.1', 6311).freeze
    end

    # Returns the default server.
    def next
      @server
    end
  end

  # Round-robin looping on a list servers or other backends.
  #
  # **IMPORTANT** the list of servers is NOT duplicated/freezed (however you
  # should be using this class with EventMachine and not bother too much about
  # thread safety). 
  # A shortcoming/feature for this is the fact that the list of servers
  # may grow or shrink with time.
  # If, by any luck, a Friday the 13th, it happens that the server list is
  # empty, and if you request the next server, it goes without saying that
  # you'll face NoMethodError on nil.
  class RoundRobinBackend < Backend
    def initialize(servers)
      super()
      raise ArgumentError, "need at least one server" if servers.empty?
      @servers = servers
    end

    # Returns the next server and shift the round-robin by one.
    def next
      @servers.unshift(@servers.pop).first.server
    end
  end

  # The UnstableBackend is a backend suitable when the pool of servers may
  # change with time (e.g., to adapt with load)
  #
  # The operation are simple: 
  # * UnstableBackend#server_found adds a server to # the list of available servers for next connections 
  # * UnstableBackend#server_lost removes a server for next connections
  #
  # The backends are polled in a round-robin fashion
  #
  # If no server is available, fibers are blocked until one is available. When
  # the first server becomes available, all pending fibers will continue to
  # this server. Note that this may have adverse consequences if many
  # connection starts in parallel.
  class UnstableBackend < Backend 

    def initialize 
      super 
      @servers = []
      @stalled_fibers = [] 
    end

    # Adds srv to the list of available servers for next connections
    # wakes up all pending fibers if any
    def server_found(srv)
      @servers << srv unless @servers.include?(srv)
      wake_up!(srv) if stalled?
    end

    # Removes srv to the list of available
    def server_lost(srv)
      @servers.delete(srv) if @servers.include?(srv)
    end

    # Returns next server, if none is available, will blocks current Fiber
    # until a server is available.
    def next
      srv = shift_servers!
      unless srv
        fib = Fiber.current
        @stalled_fibers << fib
        srv = Fiber.yield
      end
      srv
    end

    private

    # shift currently available servers in a round-robin fashion
    def shift_servers!
      srv = @servers.pop
      if srv
        @servers.unshift(srv)
        srv
      end
    end

    # true if there is any fiber to wake up
    def stalled?
      @stalled_fibers.any?
    end

    # wakes up all blocked fibers
    def wake_up!(srv)
      fibs = @stalled_fibers.dup
      fibs.each do |fib|
        fib.resume(srv) if fib
      end
      @stalled_fibers = []
    end
  end
end

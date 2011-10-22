
module EM::Rserve
  # A Backend is a way to specify connection parameters.
  # The Pooler rely on a Backend to feed him the list of places to connect.
  # A Backend must respond_to :next, which returns a server.
  class Backend
    include Enumerable

    # A Server just holds an host and a port.
    # It respond to :server answering self. The reason for this is to have
    Server = Struct.new(:host, :port) do
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
end

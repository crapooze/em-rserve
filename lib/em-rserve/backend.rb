
module EM::Rserve
  # A Backend is a way to specify connection parameters.
  # The Pooler rely on a Backend to feed him the list of places to connect.
  class Backend
    include Enumerable

    # A Server just holds an host and a port.
    Server = Struct.new(:host, :port)

    def initialize
      yield self if block_given?
    end

    def next
      raise NotImplementedError, "you should use subclasses of Backend"
    end
  end

  # The default backend: an RServe running on localhost and default port (6311)
  class DefaultBackend < Backend
    def initialize
      super
      @server = Server.new('127.0.0.1', 6311).freeze
    end

    def next
      @server
    end
  end

  # Round-robin looping on servers
  class RoundRobinBackend < Backend
    def initialize(servers)
      super()
      raise ArgumentError, "need at least one server" if servers.empty?
      @servers = servers
    end

    def next
      @servers.unshift(@servers.pop).first
    end
  end
end


require "em-rserve/connector"
require "em-rserve/parser"

module EM::Rserve
  class Connection < EM::Connection
    include Connector
  end
end


require "fiber"
require "em-rserve/connection"

module EM::Rserve
# A FiberedConnection is a type of EM::RServe::Connection but it handles every
# connection in a Ruby Fiber.
# This class also implements many high-level methods such that you don't have to understand the in and out of Ruby Fiber.
#
# It is usually enough to use the connection this way:
# EM.run do
#    Fiber.new do
#      conn = FiberedConnection.new
#      conn[:foo] = [1, 2, 3, 4]
#      conn[:bar] = [1, 2, 3, 4]
#      puts conn.call('cor(foo, bar)')
#    end.resume
#  end
#
# For some context, please read http://www.igvita.com/2010/03/22/untangling-evented-code-with-ruby-fibers/
class FiberedConnection < EM::Rserve::Connection

  # The Fiber holding the context for this connection
  attr_accessor :fiber

  # Starts a new connection, the first parameter is a Fiber to hold the context
  # of the connection, defaults to current fiber.
  # This fiber cannot be the root Fiber.
  # Remaining parameters are the same than in EM::Rserve::Connection.start
  def self.start(fiber=Fiber.current, *args)
    conn = super(*args)
    conn.fiber = fiber
    Fiber.yield 
  end

  # Called when ready, resume the Fiber execution
  def ready
    super
    fiber.resume self if fiber
  end

  # Evaluates a piece of R script and returns:
  # - script is a string (or an object that we'll transform to a string with :to_s)
  # - nil if the script doesn't return anything (it often does but not on)
  # - a Ruby object coming from the translation of a Sexp which represents an R object 
  # - WARNING: current version also return nil on error 
  # Blocks the Fiber but not the event loop.
  def call(script, *args)
    r_eval(script.to_s, *args) do |req|
      req.errback do |err|
        fiber.resume nil
      end

      req.callback do |msg|
        unless msg
          fiber.resume nil
          next
        end
        root = msg.parameters.first
        if root
          fiber.resume EM::Rserve::R::RtoRuby::Translator.r_to_ruby(root) 
        else
          fiber.resume nil
        end
      end
    end

    Fiber.yield
  end

  # Sets a symbol to a val in the R context.
  # sym will be passed verbatim to EM::Rserve::Connection#assign
  # val is a Ruby object that will get translated to a Sexp which represents an R object
  # Blocks the Fiber but not the event loop.
  def set(sym, val)
    root = EM::Rserve::R::RubytoR::Translator.ruby_to_r val

    assign(sym, root) do |req|
      req.errback do |err|
        fiber.resume nil
      end
      req.callback do |msg|
        fiber.resume val
      end
    end

    Fiber.yield
  end

  # Same thing as call, RServe doesn't provide a way to read the value of a
  # symbol although it provides a way of writing a symbol. Hence, we just
  # evaluate a script with the name of the symbol.
  # A sad side effect is the following warning:
  #
  # *WARNING* this method is unsafe because it evaluates arbitrary R Code.
  # Always check that your input parameter looks like an R symbol. 
  #
  # Blocks the Fiber but not the event loop.
  def get(sym)
    call(sym)
  end

  alias :[]= :set
  alias :[]  :get
end
end

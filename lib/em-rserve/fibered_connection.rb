
require "fiber"
require "em-rserve/connection"

module EM::Rserve
class FiberedConnection < EM::Rserve::Connection
  attr_accessor :fiber

  def self.start(fiber=Fiber.current, *args)
    conn = super(*args)
    conn.fiber = fiber
    Fiber.yield 
  end

  def ready
    super
    fiber.resume self if fiber
  end

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

  # *WARNING* this method is unsafe always check your input parameter
  def get(sym)
    call(sym)
  end

  alias :[]= :set
  alias :[]  :get
end
end

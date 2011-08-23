#example which shows how various R objects are dumped and translated in Ruby
$LOAD_PATH << './lib'

require 'em-rserve'
require 'em-rserve/qap1'
require 'em-rserve/translator'

class DevelConnection < EM::Rserve::Connection
  attr_reader :request_queue

  def dump_sexp(msg)
    raise unless msg.parameters.size == 1
    root = msg.parameters.first
    p root
    val =  EM::Rserve::Translator.r_to_ruby(root)
    p val
  end

  def dump_r_val(str) 
    r_eval(str) do |req|
      req.callback do |msg|
        dump_sexp msg
      end
    end
  end

  def assign_and_debug_node(sym, node)
    assign(sym, node) do |req|
      req.errback do |err|
        puts 'could not assign'
      end
      req.callback do |msg|
        puts 'assigned'
        dump_r_val sym.to_s
      end
    end
  end

  def do_int
    do_array_int([1])
  end

  def do_array_int(ints=[1,2,3,4,5])
    root = EM::Rserve::Sexp::Node::Root.new
    array = EM::Rserve::Sexp::Node::ArrayInt.new
    array.rb_raw = ints
    root.children << array
    assign_and_debug_node :lol, root
  end

  def do_double
    do_array_double [3.14]
  end

  def do_array_double(doubles=[1,2,3,4.2])
    root = EM::Rserve::Sexp::Node::Root.new
    array = EM::Rserve::Sexp::Node::ArrayDouble.new
    array.rb_raw = doubles
    root.children << array
    assign_and_debug_node :lol, root
  end

  def do_array_bool(bools=[true, false, nil])
    root = EM::Rserve::Sexp::Node::Root.new
    array = EM::Rserve::Sexp::Node::ArrayBool.new
    array.rb_raw = bools
    root.children << array
    assign_and_debug_node :lol, root
  end

  def do_true
    do_array_bool [true]
  end

  def do_false
    do_array_bool [false]
  end

  def do_nil
    do_array_bool [nil]
  end

  def do_string
    do_array_string ["lulzor"]
  end

  def do_array_string(strs=['for', 'great', 'justice'])
    root = EM::Rserve::Sexp::Node::Root.new
    array = EM::Rserve::Sexp::Node::ArrayString.new
    array.rb_raw = strs
    root.children << array
    assign_and_debug_node :lol, root
  end

  def do_table
  end

  def ready
    puts "ready"
    
    #do_int
    #do_double
    #do_true
    #do_false
    #do_nil
    #do_string
    
    #do_array_int
    #do_array_double
    #do_array_bool
    #do_array_string

    dump_r_val 'table(c(1,2,3,2,2))'
    return
    r_eval "data.frame(foo=c(1:8), bar=seq(100,800,100))"
    r_eval "data.frame(foo=c(1,2,3), bar=c(NA,FALSE,TRUE), row.names=c('foo','bar','baz'))" 
    r_eval 'function(a,b=2){a+b}' 
    r_eval 'ls'
    r_eval 'print'
  end

end

EM.run do
  DevelConnection.start
end

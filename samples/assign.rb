#example which shows how various R objects are dumped and translated in Ruby
$LOAD_PATH << './lib'

require 'em-rserve'
require 'em-rserve/qap1'
require 'pp'
require 'em-rserve/translator'

class DevelConnection < EM::Rserve::Connection
  attr_reader :request_queue

  def dump_sexp(msg)
    raise unless msg.parameters.size == 1
    root = msg.parameters.first
    pp root
    val =  EM::Rserve::RtoRuby::Translator.r_to_ruby(root)
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

  def loop_parse_r_val(str)
    r_eval(str) do |req|
      req.callback do |msg|
        raise unless msg.parameters.size == 1
        root = msg.parameters.first
        new_root = EM::Rserve::Sexp.parse(root.dump_sexp)
        val1 =  EM::Rserve::RtoRuby::Translator.r_to_ruby(root)
        val2 =  EM::Rserve::RtoRuby::Translator.r_to_ruby(new_root)
        if val1 == val2
          p "ok: #{str}" 
        else
          p "ko: #{str}"
        end
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

  def do_table_for_ints
    root = EM::Rserve::Sexp::Node::Root.new do |root|
      root.children << EM::Rserve::Sexp::Node::ArrayInt.new do |node|
        node.rb_raw = [1,3,1]
        node.attribute = EM::Rserve::Sexp::Node::ListTag.new do |attr|
          attr.children << EM::Rserve::Sexp::Node::ArrayInt.new do |val|
            val.rb_raw = [3]
          end
          attr.children << EM::Rserve::Sexp::Node::SymName.new do |val|
            val.rb_raw = "dim"
          end
          attr.children << EM::Rserve::Sexp::Node::Vector.new do |vector|
            vector.attribute = EM::Rserve::Sexp::Node::ListTag.new do |tags|
              tags.rb_raw = [[''], "names"] #XXX should not be necessary to correct dump
              tags.children << EM::Rserve::Sexp::Node::ArrayString.new do |strings|
                strings.rb_raw = ['']
              end
              tags.children << EM::Rserve::Sexp::Node::SymName.new do |val|
                val.rb_raw = 'names'
              end
            end
            vector.children << EM::Rserve::Sexp::Node::ArrayString.new do |strings|
              strings.rb_raw = ['1', '2', '3']
            end
            vector.rb_raw = [['1', '2', '3']] #XXX should not be needed
          end
          attr.children << EM::Rserve::Sexp::Node::SymName.new do |val|
            val.rb_raw = "dimnames"
          end
          attr.children << EM::Rserve::Sexp::Node::ArrayString.new do |val|
            val.rb_raw = ["table"]
          end
          attr.children << EM::Rserve::Sexp::Node::SymName.new do |val|
            val.rb_raw = "class"
          end
          attr.rb_raw = [[3], "dim", [["1", "2", "3"]], "dimnames", ["table"], "class"] #XXX should not be needed
        end
        root.rb_raw = [[1, 3, 1]]
      end
    end

    assign_and_debug_node :lol, root
  end

  def ready
    puts "ready"

    loop_parse_r_val 'c(1:5)'
    loop_parse_r_val 'table(c(1,2,3,2,2))'
    loop_parse_r_val "data.frame(foo=c(1:8), bar=seq(100,800,100))"
    loop_parse_r_val "data.frame(foo=c(1,2,3), bar=c(NA,FALSE,TRUE), row.names=c('foo','bar','baz'))" 
    
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

    #do_table_for_ints

    #r_eval 'table(c(1,2,3,2,2))'
    #table:
    # root 
    #  ArrayInt
    #

    return
    r_eval 'function(a,b=2){a+b}' 
    r_eval 'ls'
    r_eval 'print'
  end

end

EM.run do
  DevelConnection.start
end

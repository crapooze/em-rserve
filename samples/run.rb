#example which shows how various R objects are dumped and translated in Ruby
$LOAD_PATH << './lib'

require 'em-rserve'

class DevelConnection < EM::Rserve::Connection
  attr_reader :request_queue

  def receive_message(msg)
    super
    dump_sexp(msg)
  end

  def dump_sexp(msg)
    raise unless msg.parameters.size == 1
    root = msg.parameters.first
    catch :cannot_translate do
      val =  EM::Rserve::R::RtoRuby::Translator.r_to_ruby(root)

      p val
      return 
    end

    puts "could not translate"
    return

    node = root.children.first
    attR = node.attribute

    p [node.class, attR.class].map{|c| c.name.split('::').last}

    msg.parameters.first.descent do |node, depth|
      puts "#{depth} #{node.class} #{node.rb_raw} #{node.rb_val}"
      if node.attribute
        node.attribute.descent do |at, d|
          puts "#{depth},#{d} #{at.class} #{at.rb_raw} #{at.rb_val}"
        end
      end
    end
  end

  def unbind
    super
    p "closing"
  end

  def ready
    puts "ready"
    r_eval 'list(name="Fred", wife="Mary", no.children=3, child.ages=c(4,7,9))'
    return
    r_eval 'c(1:5)'
    r_eval 'as.factor(c("a", "a", "b", "c"))' 
    r_eval 'TRUE'
    r_eval 'FALSE'
    r_eval 'NA'
    r_eval "data(Cars93, package='MASS')"
    r_eval "cor(c(1:100), runif(1:100))"
    r_eval "cor(c(1:100), c(1:100))"
    r_eval 'table(c(1,2,3,2,2))'
    r_eval 'table(c("a", "b", "c", "a", "b"))'
    r_eval "data.frame(foo=c(1:8))"
    r_eval "data.frame(foo=c(1:8), bar=seq(100,800,100))"
    r_eval "data.frame(foo=c(1,2,3), bar=c(NA,FALSE,TRUE), row.names=c('foo','bar','baz'))" 
#    r_eval 'function(a,b=2){a+b}' 
#    r_eval 'ls'
#    r_eval 'print'
    r_eval 't.test(c(1,2,3,1),c(1,6,7,8))'
  end

end

EM.run do
  DevelConnection.start
end

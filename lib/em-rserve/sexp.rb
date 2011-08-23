
require 'em-rserve/qap1'

module EM::Rserve
  class Sexp
    include QAP1

    XT_NULL = 0
    XT_INT = 1
    XT_DOUBLE = 2
    XT_STR = 3
    XT_LANG = 4
    XT_SYM = 5
    XT_BOOL = 6
    XT_S4 = 7  

    XT_VECTOR = 16 
    XT_LIST = 17 
    XT_CLOS = 18 
    XT_SYMNAME = 19 
    XT_LIST_NOTAG = 20 
    XT_LIST_TAG = 21 
    XT_LANG_NOTAG = 22 
    XT_LANG_TAG = 23 
    XT_VECTOR_EXP = 26 
    XT_VECTOR_STR = 27 

    XT_ARRAY_INT = 32 
    XT_ARRAY_DOUBLE = 33 

    XT_ARRAY_STR = 34 
    XT_ARRAY_BOOL_UA = 35 
    XT_ARRAY_BOOL = 36 
    XT_RAW = 37 
    XT_ARRAY_CPLX = 38 
    XT_UNKNOWN = 48

    class Node
      attr_accessor :attribute
      attr_accessor :children

      def initialize
        @children = []
        @attribute = nil
        yield self if block_given?
      end

      def descent(depth=0, &blk)
        if block_given?
          blk.call(self, depth)
          @children.each do |c|
            c.descent(depth + 1, &blk)
          end
        else
          Enumerator.new(self, :descent)
        end
      end

      def dump_sexp
        body = dumped_value_with_attribute
        children_data = children.map do |n|
          n.dump_sexp
        end.join('')
        size = body.size + children_data.size
        flags = {:large => false, :attr => attribute && true}
        head = self.class.parameter_head(self.class.code, flags, size)
        [head, body + children_data].pack('Va*')
      end

      def dumped_value_with_attribute
        if attribute
          attribute.dump_sexp  + dumped_value 
        else
          dumped_value
        end
      end

      def dumped_value
        ''
      end

      def self.parameter_head(type, flags, len)
        head_bits  = type & 0x3f #high bits are for flags
        len_bits   = (len & 0xff) << 8
        flags_bits = 0
        flags_bits |= 0x40 if flags[:large]
        flags_bits |= 0x80 if flags[:attr]
        ret = head_bits | len_bits | flags_bits
        ret
      end

      class << self
        def code(val=nil)
          if val
            @code = val
          end
          @code 
        end
      end

      def self.build_map!
        all_nodes = ObjectSpace.each_object(Class).select{|k| k.ancestors.include?(self)} - [self]
        true_nodes = all_nodes.select(&:code)
        pairs = true_nodes.map{|n| [n.code, n]}
        @@map = Hash[*pairs.flatten]
      end

      def self.map
        @@map ||= build_map!
      end

      def self.class_for_type(type)
        map[type]
      end

      attr_accessor :rb_raw
      alias :rb_val :rb_raw
      alias :interpret :rb_raw=

      def int2bool(i)
        if i == 1
          true
        elsif i == 0
          false
        elsif i == 2
          nil
        else
          raise "unknown bool int: #{i}"
        end
      end

      def bool2int(b)
        if b == true
          1
        elsif b == false
          0
        elsif b.nil?
          2
        else
          raise "unknown bool for int: #{b}"
        end
      end

      # not leaves
      class ParentNode < Node
        def interpret(dat)
          @children = Sexp.decode_nodes_array(dat)
          super(children.map(&:rb_raw))
        end
      end

      class Root < ParentNode
        def rb_val
          children.first.rb_val
        end

        def dump_sexp
          children.first.dump_sexp
        end
      end

      class Null < Node
        code XT_NULL
        def interpret(dat)
          super nil
        end
      end

      class Bool < Node
        code XT_BOOL
        def interpret(dat)
          super int2bool(dat.unpack('i').first)
        end

        def dumped_value
          [bool2int(rb_raw)].pack('i')
        end
      end

      class Int < Node
        code XT_INT
        def interpret(dat)
          super dat.unpack('i').first
        end

        def dumped_value
          [rb_raw].pack('i')
        end
      end

      class Double < Node
        code XT_DOUBLE
        def interpret(dat)
          super dat.unpack('d').first
        end
      end

      class NodesArray < Node
        def rb_val
          if rb_raw.size > 1
            rb_raw
          else
            rb_raw.first
          end
        end
      end

      class String < Node
        code XT_STR
        def interpret(dat)
          val, padding = dat.split("\0", 2)
          super val
        end
      end

      class SymName < String
        code XT_SYMNAME

        def dumped_value
          ret = rb_raw + "\0"
          ret << "\0" * (ret.size % 4)
          ret
        end
      end

      class ArrayString < NodesArray
        code XT_ARRAY_STR
        def interpret(dat)
          ary = dat.split("\0")
          return(super(ary)) if ary.empty?
          ary.pop if ary.last.tr("\1",'').empty?
          super ary
        end

        def dumped_value
          str = (rb_raw + ['']).join("\0")
          str << "\1" * (str.size % 4)
          str
        end
      end

      class ArrayInt < NodesArray
        code XT_ARRAY_INT
        def interpret(dat)
          super dat.unpack('i'*(dat.size/4))
        end

        def dumped_value
          rb_raw.pack('i*')
        end
      end

      class ArrayDouble < NodesArray
        code XT_ARRAY_DOUBLE
        def interpret(dat)
          super dat.unpack('d'*(dat.size/8))
        end

        def dumped_value
          rb_raw.pack('d*')
        end
      end

      class ArrayBool < NodesArray
        code XT_ARRAY_BOOL

        def interpret(dat)
          cnt, dat = dat.unpack('ia*')
          super dat.unpack('c'*cnt).map{|i| int2bool(i)}
        end

        def dumped_value
          ([rb_raw.size] + rb_raw.map{|v| bool2int(v)}).pack('ic*')
        end
      end

      class NodesList < ParentNode
      end

      class ListTag < NodesList
        code XT_LIST_TAG

        def rb_val
          ary = children.map(&:rb_val)
          hash = Hash.new
          ary.each_slice(2){|v,k| hash[k] = v}
          hash
        end
      end

      class ListNoTag < NodesList
        code XT_LIST_NOTAG
      end

      class NodesLang < ParentNode
      end

      class LangTag < NodesLang
        code XT_LANG_TAG
      end

      class LangNoTag < NodesLang
        code XT_LANG_NOTAG
      end

      class Vector < ParentNode
        code XT_VECTOR
      end

      class Raw < Node
        code XT_RAW
        def interpret(dat)
          cnt,dat=dat.unpack('ia*')
          super dat.slice(0,cnt)
        end
      end

      class Unknown < Node
        code XT_UNKNOWN
      end

      class Closure < ParentNode
        code XT_CLOS 
      end

      class S4 < ParentNode
        code XT_S4 
      end
    end

    def self.parse(dat)
      node = Node::Root.new
      node.interpret(dat)
      node
    end

    def self.head_parameter(head)
      type = head & 0x3f #high bits are for flags
      large_flag = !(head & 0x40 == 0) #  i.e. 1 << 6 (64)
      attr_flag = !(head & 0x80 == 0)  #  i.e. 1 << 7 (128)
      len  = (head & ~0xff) >> 8
      flags = {large: large_flag, attr: attr_flag}
      [type, flags, len]
    end

    # debugging function
    def self.xt_type_sym(type)
      self.constants.find{|c| self.const_get(c) == type}
    end

    # debugging function
    def self.announce(str)
      # puts "A:#{str}"
    end

    # Decodes a buffer given a type of node
    def self.decode_node(type, buffer)
      announce [xt_type_sym(type), "0x%02x" % type, buffer.size, buffer].inspect
      klass = Node.class_for_type(type)
      if klass
        node = klass.new
        node.interpret(buffer)
        node
      else
        raise RuntimeError, "no Node to decode type #{type}"
      end
    end

    # Decodes a buffer starting with a header
    # returns an array of two elements:
    # - the new, interpreted Node
    # - the remainder of the buffer
    def self.decode_nodes(buffer)
      head, buffer = buffer.unpack('Va*')
      type, flags, len = head_parameter(head)

      # Cuts the buffer at the correct length and give away the remainder
      buffer, remainder = buffer.unpack("a#{len}a*")

      attrs = nil
      if flags[:attr]
        attrs, buffer = decode_nodes(buffer) 
      end

      node = decode_node(type, buffer)

      node.attribute = attrs if attrs

      [node, remainder]
    end

    def self.decode_nodes_array(buffer)
      ary = []
      until buffer.empty?
        val, buffer = decode_nodes(buffer)
        ary << val
      end
      ary
    end
  end
end

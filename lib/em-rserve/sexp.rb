
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

      def interpret(dat)
      end

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

      # not leaves
      class ParentNode < Node
        def interpret(dat)
          @children = Sexp.decode_nodes_array(dat)
        end
      end

      class Root < ParentNode
      end

      class Null < Node
        code XT_NULL
        def interpret(dat)
          nil
        end
      end

      class Bool < Node
        code XT_BOOL
        def interpret(dat)
          int2bool(dat.unpack('i').first)
        end
      end

      class Int < Node
        code XT_INT
        def interpret(dat)
          dat.unpack('i').first
        end
      end

      class Double < Node
        code XT_DOUBLE
        def interpret(dat)
          dat.unpack('d').first
        end
      end

      class NodesArray < Node
      end

      class String < Node
        code XT_STR
        def interpret(dat)
          val, padding = dat.split("\0", 2)
          val
        end
      end

      class SymName < String
        code XT_SYMNAME
      end

      class ArrayString < NodesArray
        code XT_ARRAY_STR
        def interpret(dat)
          ary = dat.split("\0")
          return ary if ary.empty?
          ary.pop if ary.last.tr("\1",'').empty?
          ary
        end
      end

      class ArrayInt < NodesArray
        code XT_ARRAY_INT
        def interpret(dat)
          dat.unpack('V' * (dat.size/4))
        end
      end

      class ArrayDouble < NodesArray
        code XT_ARRAY_DOUBLE
        def interpret(dat)
          dat.unpack('d'*(dat.size/8))
        end
      end

      class ArrayBool < NodesArray
        code XT_ARRAY_BOOL

        def interpret(dat)
          cnt, dat = dat.unpack('ia*')
          dat.unpack('c'*cnt).map{|i| int2bool(i)}
        end
      end

      class NodesList < ParentNode
      end

      class ListTag < NodesList
        code XT_LIST_TAG
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

      class Vector < Node
        code XT_VECTOR
      end

      class Raw < Node
        code XT_RAW
        def interpret(dat)
          cnt,dat=dat.unpack('ia*')
          dat.slice(0,cnt)
        end
      end

      class Closure < ParentNode
        code XT_CLOS 
      end
    end

    def self.parse(dat)
      Node::Root.new.interpret(dat)
    end

    def self.head_parameter(head)
      type = head & 0x0000003f #high bits are for flags
      large_flag = !(head & 0x40 == 0) #  i.e. 1 << 6 (64)
      attr_flag = !(head & 0x80 == 0)  #  i.e. 1 << 7 (128)
      len  = (head & 0xffffff00) >> 8
      flags = {large: large_flag, attr: attr_flag}
      [type, flags, len]
    end

    def self.xt_type_sym(type)
      self.constants.find{|c| self.const_get(c) == type}
    end

    # debugging function
    def self.announce(str)
       puts "A:#{str}"
    end

    # Decodes a buffer given a type of node
    def self.decode_node(type, buffer)
      announce [xt_type_sym(type), "0x%02x" % type, buffer.size, buffer].inspect
      klass = Node.class_for_type(type)
      if klass
        node = klass.new
        val = node.interpret(buffer)
        #announce val.inspect
        node
      else
        raise RuntimeError, "no Node to decode type #{type}"
      end
    end

    # Decodes a buffer reading starting with a header
    # returns an array of two elements:
    # - the new, interpreted Node
    # - the remainder of the buffer
    def self.decode_nodes(buffer)
      head, buffer = buffer.unpack('Va*')
      type, flags, len = head_parameter(head)
      #announce "reading: #{len}"
      attrs = nil
      if flags[:attr]
        attrs, buffer = decode_nodes(buffer) 
      end

      node = decode_node(type, buffer.slice(0, len))

      node.attribute = attrs if attrs

      [node, buffer.slice(len .. -1)]
    end

    def self.decode_nodes_array(buffer)
      ary = []
      until buffer.nil? or buffer.empty?
        val, buffer = decode_nodes(buffer)
        ary << val
      end
      ary
    end

  end
end

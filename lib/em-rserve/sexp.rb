
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

      def interpret(dat, len)
      end

      class Null < Node
        code XT_BOOL

        def interpret(dat, len)
          nil
        end
      end

      class Int < Node
        code XT_INT
        def interpret(dat, len)
          dat.unpack('i').first
        end
      end

      class Double < Node
        code XT_DOUBLE
        def interpret(dat, len)
          dat.unpack('d').first
        end
      end

      class NodesArray < Node
      end

      class String < Node
        code XT_STR
        def interpret(dat, len)
          val, padding = dat.split("\0", 2)
          val
        end
      end

      class SymName < String
        code XT_SYMNAME
      end

      class ArrayString < NodesArray
        code XT_ARRAY_STR
        def interpret(dat, len)
          ary = dat.slice(0, len).split("\0")
          return ary if ary.empty?
          ary.pop if ary.last.tr("\1",'').empty?
          ary
        end
      end

      class ArrayInt < NodesArray
        code XT_ARRAY_INT
        def interpret(dat, len)
          dat.unpack('V' * (len/4))
        end
      end

      class ArrayDouble < NodesArray
        code XT_ARRAY_DOUBLE
        def interpret(dat, len)
          dat.unpack('d' * (len/8))
        end
      end

      class NodesList < Node
      end

      class ListTag < NodesList
        code XT_LIST_TAG
        def interpret(dat, len)
          ary = []
          until dat.empty? #XXX may stop earlier
            val, dat = Sexp.decode_nodes(dat)
            ary << val
          end
          ary
        end
      end
    end

    def self.parse(dat)
      obj = self.new
      decode_nodes(dat)
      obj
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

    # Decodes a buffer given a type of node
    def self.decode_node(type, buffer)
      p [xt_type_sym(type), "0x%02x" % type, buffer.size, buffer]
      klass = Node.class_for_type(type)
      if klass
        node = klass.new
        val = node.interpret(buffer, buffer.size)
        p val
        node
      else
        raise RuntimeError, "no Node to decode type #{type}"
      end
    end

    # Decodes a buffer reading starting with a header
    def self.decode_nodes(buffer)
      head, buffer = buffer.unpack('Va*')
      type, flags, len = head_parameter(head)

      if flags[:attr]
        attrs, buffer = decode_nodes(buffer)
      end

      node = decode_node(type, buffer.slice(0, len))

      [node, buffer.slice(len .. -1)]
    end
  end
end

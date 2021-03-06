
require 'em-rserve/r/sexp'

module EM::Rserve
  module R
    module RtoRuby
      class Translator
        def self.r_to_ruby(root)
          node = root.children.first
          attR = node.attribute

          pair = [node.class, attR.class]
          klass = case pair
                  when [Sexp::Node::ArrayInt, NilClass]
                    ArrayTranslator
                  when [Sexp::Node::ArrayBool, NilClass]
                    ArrayTranslator
                  when [Sexp::Node::ArrayString, NilClass]
                    ArrayTranslator
                  when [Sexp::Node::ArrayDouble, NilClass]
                    ArrayTranslator
                  when [Sexp::Node::ArrayComplex, NilClass]
                    ArrayTranslator
                  when [Sexp::Node::ArrayDouble, Sexp::Node::ListTag]
                    DateTranslator
                  when [Sexp::Node::ArrayInt, Sexp::Node::ListTag]
                    FactorTableTranslator
                  when [Sexp::Node::Vector, Sexp::Node::ListTag]
                    DataFrameTranslator
                  when [Sexp::Node::Closure, NilClass]
                    ClosureTranslator
                  else
                    DefaultTranslator
                  end
          klass.new(node).translate 
        end

        attr_reader :node

        def initialize(node=nil)
          @node = node
        end

        def translate
          throw :cannot_translate
        end

        class DefaultTranslator < Translator
        end

        class ArrayTranslator < Translator
          def translate
            node.rb_val
          end
        end

        class DateTranslator < Translator
          def translate
            case node.attribute.rb_val['class']
            when 'Date'
              Time.at(node.rb_val * 86400) # R gives days Ruby wants secs
            else
              super
            end
          end
        end

        class FactorTableTranslator < Translator
          # Symbols represented by ints
          class Factor < Array
            attr_accessor :levels
          end

          # Frequency table
          class Table < Hash
          end

          def translate_factor
            levels = node.attribute.rb_val['levels']
            levels = levels.map{|str| str.to_sym}
            ret = Factor.new.replace(node.rb_val.map{|i| levels[i-1]})
          end

          def translate_table
            keys = node.attribute.rb_val['dimnames'].first
            vals = node.rb_val
            Table[ keys.zip(vals) ]
          end

          def translate
            case node.attribute.rb_val['class']
            when 'factor'
              translate_factor
            when 'table'
              translate_table
            else
              super
            end
          end
        end

        class DataFrameTranslator < Translator
          class DataFrame < Hash
            attr_accessor :rows, :r_class

            def inspect
              super.sub(/}$/," @r_class: #{r_class}, @rows: #{rows}")
            end

            def each_struct
              if block_given?
                all_keys = keys #not sure keys will always return the same order
                struct = Struct.new(*all_keys.map(&:to_sym))
                #XXX when we map and transpose, we actually do computation before they
                #are needed, could improve with true-style iterators
                all_keys.map{|k| self[k]}.transpose.each do |values|
                  yield struct.new(*values)
                end
              else
                Enumerator.new(:self, :each_struct)
              end
            end
          end

          def translate_data_frame
            attrs = node.attribute.rb_val
            cols = [attrs['names']].flatten
            rows = case attrs['row.names']
                   when [-2147483648, -8]
                     nil
                   else
                     [attrs['row.names']].flatten
                   end

            dfrm = DataFrame[ cols.zip(node.rb_val) ]
            dfrm.rows = rows if rows
            dfrm
          end

          def translate
            h = translate_data_frame
            h.r_class = node.attribute.rb_val['class']
            h
          end
        end

        class ClosureTranslator < Translator
        end
      end
    end
  end
end

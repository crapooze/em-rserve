require 'em-rserve/r/sexp'

module EM::Rserve
  module R
    module RubytoR
      class Translator

        def self.translator_klass_for(obj)
          case obj
          when Array
            ArrayTranslator
          when Hash
            HashTranslator
          else
            SingleObjectTranslator
          end
        end

        def self.ruby_to_r(obj)
          translator_klass_for(obj).new(obj).translate 
        end

        attr_reader :obj

        def initialize(obj=nil)
          @obj = obj
        end

        def translate
          throw :cannot_translate
        end

        class SingleObjectTranslator < Translator
          def translate
            Translator.ruby_to_r [obj]
          end
        end

        class ArrayTranslator < Translator
          MAPPING = {String => EM::Rserve::R::Sexp::Node::ArrayString,
            Integer => EM::Rserve::R::Sexp::Node::ArrayInt,
            Float => EM::Rserve::R::Sexp::Node::ArrayDouble,
            NilClass => EM::Rserve::R::Sexp::Node::ArrayBool,
            TrueClass => EM::Rserve::R::Sexp::Node::ArrayBool,
            FalseClass => EM::Rserve::R::Sexp::Node::ArrayBool,
          }

          def array_node_class
            classes = obj.map(&:class).uniq
            if classes.size == 1
              obj_klass = classes.first
              MAPPING.each_pair do |klass, node|
                return node if obj_klass.ancestors.include?(klass)
              end
            elsif (classes - [TrueClass,NilClass,FalseClass]).empty?
              EM::Rserve::R::Sexp::Node::ArrayBool
            elsif (classes - [Float, Fixnum]).empty?
              EM::Rserve::R::Sexp::Node::ArrayDouble
            else
              nil
            end
          end

          def translate
            klass = array_node_class
            throw :cannot_translate unless klass
            EM::Rserve::R::Sexp::Node::Root.new do |root|
              klass.new do |array|
                array.rb_raw = obj
                root.children << array
              end
            end
          end
        end

        class HashTranslator < Translator
          def list_node_class
            EM::Rserve::R::Sexp::Node::Vector
          end

          def list_node_attribute_class
            EM::Rserve::R::Sexp::Node::ListTag
          end

          def translate
            klass = list_node_class
            attr_klass = list_node_attribute_class
            throw :cannot_translate unless klass and attr_klass
            raise :cannot_translate if obj.empty?
            pairs = obj.each_pair.to_a
            size = pairs.first.last.size
            #TODO: check if sizes differ and raise
            EM::Rserve::R::Sexp::Node::Root.new do |root|
              klass.new do |vector|
                vector.attribute = attr_klass.new do |taglist|
                  # add ArrayString with keys as strings for column names
                  # add SymName "names"
                  taglist.children << ArrayTranslator.new(pairs.map(&:first).map(&:to_s)).translate.children.first
                  sym = EM::Rserve::R::Sexp::Node::SymName.new
                  sym.rb_raw = "names"
                  taglist.children << sym
                  # add ArrayInt -2147483648, -(size) for rows
                  # add SymName "row.names"
                  taglist.children << ArrayTranslator.new([-2147483648, 0 - size]).translate.children.first
                  sym = EM::Rserve::R::Sexp::Node::SymName.new
                  sym.rb_raw = "row.names"
                  taglist.children << sym

                  # add ArrayString "data.frame"
                  # add SymName "class"
                  taglist.children << ArrayTranslator.new(["data.frame"]).translate.children.first
                  sym = EM::Rserve::R::Sexp::Node::SymName.new
                  sym.rb_raw = "class"
                  taglist.children << sym
                end #attribute

                pairs.each do |k,values|
                  array_node = ArrayTranslator.new(values).translate.children.first
                  vector.children << array_node
                end #children
                root.children << vector
              end #vector
            end
          end
        end

      end
    end
  end
end


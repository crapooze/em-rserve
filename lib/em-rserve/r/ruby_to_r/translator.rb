require 'em-rserve/r/sexp'

module EM::Rserve
  module R
    module RubytoR
      class Translator

        def self.ruby_to_r(obj)
          klass = case obj
                  when Array
                    ArrayTranslator
                  when Hash
                    HashTranslator
                  else
                    DefaultTranslator
                  end
          klass.new(node).translate 
        end

        attr_reader :obj

        def initialize(obj=nil)
          @obj = obj
        end

        def translate
          throw :cannot_translate
        end

        class DefaultTranslator < Translator
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

      end
    end
  end
end


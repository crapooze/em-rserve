require File.join(File.dirname(__FILE__), 'spec_helper')
require 'em-rserve/r/ruby_to_r/translator'
require 'em-rserve/r/sexp'

describe EM::Rserve::R::RubytoR::Translator do
  include EM::Rserve::R::RubytoR

  it "should throw :cannot_translate when cannot translate" do
    thrown=true
    catch :cannot_translate do
      Translator.new.translate
      thrown=false
    end
    thrown.should be_true
  end

  it "should remember the object" do
    tr = Translator.new(:foobar)
    tr.obj.should eql(:foobar)
  end
end

describe EM::Rserve::R::RubytoR::Translator::ArrayTranslator do
  include EM::Rserve::R

  def translator(obj)
    EM::Rserve::R::RubytoR::Translator::ArrayTranslator.new obj
  end

  def node_class_for(obj)
    translator(obj).array_node_class
  end

  it "should propose arrays of bools" do
    node_class_for([true, true, false, nil]).should eql(Sexp::Node::ArrayBool)
  end

  it "should propose arrays of ints" do
    node_class_for([1, 2, 3]).should eql(Sexp::Node::ArrayInt)
  end

  it "should propose arrays of doubles" do
    node_class_for([1.2, 2.0, Math::PI]).should eql(Sexp::Node::ArrayDouble)
  end

  it "should propose arrays of strings" do
    node_class_for(["chunky", "bacon"]).should eql(Sexp::Node::ArrayString)
  end

  it "should propose arrays of doubles for mixes of floats and fixnums" do
    node_class_for([1.5, 3]).should eql(Sexp::Node::ArrayDouble)
  end
end

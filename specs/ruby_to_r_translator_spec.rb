require File.join(File.dirname(__FILE__), 'spec_helper')
require 'em-rserve/r/ruby_to_r/translator'
require 'em-rserve/r/sexp'

describe EM::Rserve::R::RubytoR::Translator do
  include EM::Rserve::R::RubytoR

  it "should remember the object" do
    tr = Translator.new(:foobar)
    tr.obj.should eql(:foobar)
  end

  it "should throw :cannot_translate when cannot translate" do
    thrown=true
    catch :cannot_translate do
      Translator.new.translate
      thrown=false
    end
    thrown.should be_true
  end

  it "should translate simple arrays" do
    thrown=true
    catch :cannot_translate do
      Translator.ruby_to_r([1, 2, 3])
      Translator.ruby_to_r([1, 2.2, 3.2])
      Translator.ruby_to_r([true, false, nil])
      Translator.ruby_to_r(["we", "miss", "you", "_why"])
      thrown=false
    end
    thrown.should be_false
  end

  it "should translate simple values" do
    thrown=true
    catch :cannot_translate do
      Translator.ruby_to_r(1)
      Translator.ruby_to_r(1.0)
      Translator.ruby_to_r(false)
      Translator.ruby_to_r(nil)
      Translator.ruby_to_r(true)
      Translator.ruby_to_r("hello world")
      thrown=false
    end
    thrown.should be_false
  end

  it "should translate simple hashes" do
    thrown=true
    catch :cannot_translate do
      Translator.ruby_to_r({'foo' => [1,2,3,4], 'bar' => ['a', 'b', 'c', 'd']})
      thrown=false
    end
    thrown.should be_false
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

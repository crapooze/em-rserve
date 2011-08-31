require File.join(File.dirname(__FILE__), 'spec_helper')
require 'em-rserve/protocol/parser'

describe EM::Rserve::Protocol::Parser, 'initialized' do
  before :each do
    @parser = EM::Rserve::Protocol::Parser.new(:foobar)
  end

  it "should have an empty buffer" do
    @parser.buffer.should be_empty
  end

  it "should remember the handler" do
    @parser.handler.should eql(:foobar)
  end
end

describe EM::Rserve::Protocol::Parser, 'replacement' do
  before :each do
    @parser = EM::Rserve::Protocol::Parser.new(:foo)
    @new_parser = EM::Rserve::Protocol::Parser.new(:bar)
  end

  it "should replace the buffer but not the handler" do
    @parser.buffer << "foobar" #XXX we directly manipulate the buffer here
    @new_parser.replace(@parser)
    @new_parser.handler.should eql(:bar)
    @new_parser.buffer.should eql("foobar")
  end
end

describe EM::Rserve::Protocol::Parser, 'loop guard for topklass' do
  before :each do
    @parser = EM::Rserve::Protocol::Parser.new(:foo)
  end

  it "should ask for subclassing" do
    lambda {
      @parser << "lulz"
    }.should raise_error(NotImplementedError)
  end
end

describe EM::Rserve::Protocol::Parser, 'loop mechanics for subklasses' do
  before :each do
    m = Module.new do
      attr_accessor :test_proc
      def parse!
        test_proc.call
      end
    end

    @parser = EM::Rserve::Protocol::Parser.new(:foo)
    @parser.extend m
  end

  it "should loop until we throw :stop when we call the loop" do
    idx = 0
    limit = 123
    @parser.test_proc = lambda do
      idx += 1
      throw :stop if idx == limit
    end

    @parser.parse_loop!
    idx.should eql(limit)
  end

  it "should call the loop when we add data" do
    idx = 0
    limit = 123
    @parser.test_proc = lambda do
      idx += 1
      throw :stop if idx == limit
    end

    @parser << "for great justice"
    idx.should eql(limit)
  end
end

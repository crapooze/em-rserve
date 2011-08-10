require File.join(File.dirname(__FILE__), 'spec_helper')
require 'em-rserve/parser'

describe EM::Rserve::IDParser do
  before :each do
    @receiver = Class.new do
      attr_accessor :test_block
      def receive_id(id)
        test_block.call(id)
      end
    end.new 

    @parser = EM::Rserve::IDParser.new(@receiver)
  end

  it "should slice stuff in IDs of 4 bytes" do
    idx = 0
    count = 3
    @receiver.test_block = lambda do |id|
      idx += 1
      id.should be_a(EM::Rserve::ID)
      id.string.should eql('1234')
    end
    @parser << ("1234"*count)
    idx.should eql(3)
  end

  it "should not bother about chunked input" do
    idx = 0
    count = 3
    @receiver.test_block = lambda do |id|
      idx += 1
      id.should be_a(EM::Rserve::ID)
      id.string.should eql('1234')
    end
    count.times do |t|
      @parser << "1"
      @parser << "23"
      idx.should eql(t)
      @parser << "4"
    end
    idx.should eql(3)
  end
end


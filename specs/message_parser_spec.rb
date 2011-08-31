
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'em-rserve/protocol/parser'

describe EM::Rserve::Protocol::MessageParser do
  before :each do
    @receiver = Class.new do
      attr_accessor :h_test_block
      attr_accessor :m_test_block
      def receive_message_header(h)
        h_test_block.call(h)
      end
      def receive_message(m)
        m_test_block.call(m)
      end
    end.new 

    @parser = EM::Rserve::Protocol::MessageParser.new(@receiver)
  end

  it "should read a header after 16bytes" do
    idx = 0
    @receiver.h_test_block = lambda do |h|
      idx += 1
      h.should be_a(EM::Rserve::QAP1::Header)
    end
    @parser << ("\0" * 16)
    idx.should eql(1)
  end

  it "should read a header after 16bytes, even if data is chunked" do
    idx = 0
    @receiver.h_test_block = lambda do |h|
      idx += 1
      h.should be_a(EM::Rserve::QAP1::Header)
    end
    16.times { @parser << "\0" }
    idx.should eql(1)
  end


  it "should read a message whose length is specified in the header and data is sliced" do
    hack = Module.new do
      attr_accessor :message_length
    end
    #XXX this is actual, valid data, we should split the slicing and parsing
    message = "0a 0c 00 00  21 08 00 00    00 00 00 00  00 00 f0 3f".split.
      pack('H2'*16)

    @receiver.h_test_block = lambda do |m|
      m.should be_a(EM::Rserve::QAP1::Header)
      # Here we overwrite the header to not care about header's content in this spec
      m.extend hack
      m.message_length = message.length
    end

    idx = 0
    @receiver.m_test_block = lambda do |m|
      idx += 1
      m.should be_a(EM::Rserve::QAP1::Message)
    end

    stream = ("\0" * 16) + message
    stream.split('').each do |char|
      idx.should eql(0)
      @parser << char
    end
    idx.should eql(1)
  end
end

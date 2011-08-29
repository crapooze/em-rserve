
require 'em-rserve/qap1/rpack'

module EM::Rserve
  class Message
    extend Rpack

    def self.from_bin(dat)
      new decode_parameters(dat)
    end

    attr_reader :parameters

    def initialize(params=[])
      @parameters = params
    end

    def pack_parameters
      parameters.map{|p| self.class.encode_parameter(p)}.join
    end

    alias :to_bin :pack_parameters
  end
end

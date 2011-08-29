
require "em-rserve/connector"
require "em-rserve/parser"
require "em-rserve/request"
require "em-rserve/header"
require "em-rserve/message"
require "em-rserve/qap1"

module EM::Rserve
  class Connection < EM::Connection
    include Connector

    def shutdown!(&blk)
      header = Header.new(QAP1::CMD_shutdown,0,0,0)
      send_data header.to_bin

      request(&blk) 
    end

    def r_eval(string, void=false,&blk)
      data = Message.encode_string(string)
      if void
        header = Header.new(0x0002, data.length, 0, 0)
      else
        header = Header.new(0x0003, data.length, 0, 0)
      end
      send_data header.to_bin
      send_data data

      request(&blk)
    end

    def login(user,pwd, crypted=true, &blk)
      raise NotImplementedError, "will come later"
      #XXX need to read the salt during connection setup
      cifer = crypted ? pwd : crypt(pwd, salt)
      data = Message.encode_string([user, cifer].join("\n"))
      header = Header.new(QAP1::CMD_login, data.length, 0, 0)
      send_data header.to_bin
      send_data data

      request(&blk)
    end

    def detach(&blk)
      header = Header.new(QAP1::CMD_detachSession, 0, 0, 0)
      send_data header.to_bin #port, key of 20 bytes

      request(&blk)
    end

    def attach(key, &blk)
      #XXX it seems that there is no need to send a Header + Message, and
      #raw_writing because the server does a read of 32 bytes on newly accepted
      #connections
      raise ArgumentError, "wrong key length, Rserve wants 32bytes" unless key.size == 32
      send_data key

      request(&blk)
    end

    def assign(symbol, sexp_node, parse_symbol_name=true, &blk)
      data = Message.new([symbol.to_s, sexp_node]).to_bin
      data << "\xFF" * data.length % 4
      header = if parse_symbol_name
                 Header.new(QAP1::CMD_setSEXP, data.length, 0, 0)
               else
                 Header.new(QAP1::CMD_assignSEXP, data.length, 0, 0)
               end
      send_data header.to_bin
      send_data data

      request(&blk)
    end

    # MISSING:
    #   - open/close/delete/read/write files
    #   - set encoding
    #   - set buffer size
    #   - control commands
    #   - serial commands
  end
end

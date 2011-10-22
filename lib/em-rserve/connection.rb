
require "em-rserve/protocol/connector"
require "em-rserve/protocol/parser"
require "em-rserve/protocol/request"
require "em-rserve/qap1/constants"
require "em-rserve/qap1/header"
require "em-rserve/qap1/message"

module EM::Rserve
  # A Connection speaks to RServe using the methods in Protocol::Connector
  # In addition, a Connection implements helper methods to call RServe commands.
  class Connection < EM::Connection
    include Protocol::Connector
    include QAP1

    # Asks the server to close the connection.
    # Note that this does not close the TCP connection yet because you will
    # receive an acknowledgement first.
    #
    # Returns and pass to the optional block a new Request instance. See
    # Protocol::Connector#request.
    def shutdown!(&blk)
      header = Header.new(Constants::CMD_shutdown,0,0,0)
      send_data header.to_bin

      request(&blk) 
    end

    # Evaluates a R-code string in the R session
    #
    # Returns and pass to the optional block a new Request instance. See
    # Protocol::Connector#request.
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

    # Logs-in if the RServe connection asks for a user/password pair
    #
    # Returns and pass to the optional block a new Request instance. See
    # Protocol::Connector#request.
    def login(user, pwd, crypted=true, &blk)
      raise NotImplementedError, "will come later"
      #XXX need to read the salt during connection setup
      cifer = crypted ? pwd : crypt(pwd, salt)
      data = Message.encode_string([user, cifer].join("\n"))
      header = Header.new(Constants::CMD_login, data.length, 0, 0)
      send_data header.to_bin
      send_data data

      request(&blk)
    end

    # Detaches current session, the response will hold a key to later re-attach
    # the session.
    #
    # Returns and pass to the optional block a new Request instance. See
    # Protocol::Connector#request.
    def detach(&blk)
      header = Header.new(Constants::CMD_detachSession, 0, 0, 0)
      send_data header.to_bin #port, key of 20 bytes

      request(&blk)
    end

    # Attaches to the session using the secret key.
    #
    # Returns and pass to the optional block a new Request instance. See
    # Protocol::Connector#request.
    def attach(key, &blk)
      #XXX it seems that there is no need to send a Header + Message. We can
      #just write the key because the RServe code does a read of 32 bytes on newly
      #accepted connections and tests the key.
      raise ArgumentError, "wrong key length, Rserve wants 32bytes" unless key.size == 32 
      send_data key

      request(&blk)
    end

    # Assign an R object (represented by a Ruby instance of Sexp) to a symbol
    # within the context of the connection.  symbol must respond to :to_s, this
    # value will be the symbol name in R.
    # If parse_symbol_name is true, RServe will verify whether the R symbol is
    # a legal symbol.
    #
    # Returns and pass to the optional block a new Request instance. See
    # Protocol::Connector#request.
    def assign(symbol, sexp_node, parse_symbol_name=true, &blk)
      data = Message.new([symbol.to_s, sexp_node]).to_bin
      data << "\xFF" * data.length % 4
      header = if parse_symbol_name
                 Header.new(Constants::CMD_setSEXP, data.length, 0, 0)
               else
                 Header.new(Constants::CMD_assignSEXP, data.length, 0, 0)
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

#this sample will detach a session and reattach a session in a new connection
$LOAD_PATH << './lib'

require 'em-rserve'

$KEYPORT = false

class DevelConnection < EM::Rserve::Connection
  attr_reader :request_queue

  def post_init
    super
    if $KEYPORT
      replace_parser! EM::Rserve::Protocol::MessageParser
      key = $KEYPORT.last
      attach key do |req|
        req.callback do |msg|
          p "attached"
          shutdown!
        end
        req.errback do |err|
          p "not attached"
        end
      end
      r_eval "ls()" do |req|
        req.callback do |msg|
          p msg
        end
        req.errback do |err|
          p err
        end
      end
      #shutdown!
    end
  end

  def ready
    p "ready"
    if $KEYPORT
      key = $KEYPORT.last
    else
      r_eval "a <- c(1:10)"
      detach do |d|
        d.callback do |msg|
          puts "detached"
          $KEYPORT = msg.parameters
          port = $KEYPORT.first
          puts "connecting: #{port}"
          EM::next_tick do
            DevelConnection.start('127.0.0.1', port)
          end
        end
      end
    end
  end

  def detach
    puts "detaching"
    super
  end

  def attach(key, &blk)
    puts "attaching"
    super
  end
end

EM.run do
  DevelConnection.start
end

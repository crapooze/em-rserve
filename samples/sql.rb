# this example requires 
#   rubygems: sequel and the sqlite3 adapter
#   R:        RSQLite package
# first run this script with 'create' argument to generate a simple table
require 'sequel'

DB = Sequel.sqlite('dat.sqlite')
items = DB[:items]

if ARGV.include?('create')
  DB.create_table :items do
    primary_key :id
    String :name
    Float :price
    Float :sells
  end

  100.times do |t|
    price = rand(t)*100
    sells = rand(Math.sqrt(price))
    items.insert(:name => 'abc', 
                 :price => price,
                 :sells => sells)
  end
end

$code = items.filter(:name => 'abc').sql
p $code

DB.disconnect

$LOAD_PATH << './lib'

require 'em-rserve'
require 'em-rserve/qap1'
require 'em-rserve/translator'

class DevelConnection < EM::Rserve::Connection
  attr_reader :request_queue

  def dump_sexp(msg)
    raise unless msg.parameters.size == 1
    root = msg.parameters.first
    node = root.children.first
    catch :cannot_translate do
      val =  EM::Rserve::RtoRuby::Translator.r_to_ruby(root)
      p val
    end
  end

  def ready
    puts "ready"
    r_eval "library(DBI)", true do |q|
      q.errback do |err|
        p "error loading DBI"
      end
      q.callback do |msg|
        p "DBI loaded"
      end
    end
    r_eval "library(RSQLite)", true do |q|
      q.errback do |err|
        p "error loading RSQLite"
      end
      q.callback do |msg|
        p "RSQLite loaded"
      end
    end
    r_eval "driver <- dbDriver('SQLite')", true do |q|
      q.errback do |err|
        p "error driving RSQLite"
      end
      q.callback do |msg|
        p "RSQLite driver"
      end
    end
    code = "con <- dbConnect(driver, \"#{File.expand_path('dat.sqlite')}\")"
    puts code
    r_eval(code, true) do |q|
      q.errback do |err|
        p "error connecting RSQLite"
      end
      q.callback do |msg|
        p "RSQLite connected"
      end
    end
    code = "query <- dbSendQuery(con, statement = \"#{$code}\")"
    puts code
    r_eval(code, true) do |q|
      q.errback do |err|
        p "error querying RSQLite"
      end
      q.callback do |msg|
        p "RSQLite queried"
      end
    end
    r_eval "dat <- fetch(query)", true do |q|
      q.errback do |err|
        p "error fecthing query"
      end
      q.callback do |msg|
        p "query fetched"
      end
    end
    r_eval "sqliteCloseResult(query)", true do |q|
      q.errback do |err|
        p "error closing query"
      end
      q.callback do |msg|
        p "query closed"
      end
    end
    r_eval "sqliteCloseConnection(con)", true do |q|
      q.errback do |err|
        p "error closing connection"
      end
      q.callback do |msg|
        p "connection closed"
      end
    end
    r_eval "sqliteCloseDriver(driver)", true do |q|
      q.errback do |err|
        p "error closing driver"
      end
      q.callback do |msg|
        p "driver closed"
      end
    end

    # dataframes are mapped to subclasses of Hashes which respond_to :each_struct
    r_eval "dat" do |q|
      q.errback do |err|
        p "error getting dat"
      end
      q.callback do |msg|
        p "got dat"
        root = msg.parameters.first
        node = root.children.first
        catch :cannot_translate do
          val =  EM::Rserve::RtoRuby::Translator.r_to_ruby(root)
          val.each_struct do |st|
            p st
          end
        end
      end
    end

    # vectors of doubles with a single item are mapped to a single double
    r_eval "cor(dat$sells, dat$price)" do |q|
      q.errback do |err|
        p "error getting correlation"
      end
      q.callback do |msg|
        p "got correlation"
        dump_sexp(msg)
      end
    end
    r_eval "c(1:10)" 
  end

end

EM.run do
  # EM::Rserve::Connection.start
  DevelConnection.start
end




$LOAD_PATH << './lib'
require 'sinatra'
require 'em-rserve'
require 'em-rserve/pooler'
require 'fileutils'

FileUtils.mkdir_p 'plots'

get '/' do
  redirect :plot
end

helpers do
  def backend
    unless defined?(@@backend)
      # shows how to use backend and servers in a round-robin, for people who want
      # to build crazy clusters of RServes
      servers = []
      servers << EM::Rserve::DefaultBackend.new #this is a Backend object
      servers << EM::Rserve::DefaultBackend.new.next #this is a Backend::Server object
      @@backend = EM::Rserve::RoundRobinBackend.new(servers)
    end
    @@backend
  end

  def pool
    @@pool ||= EM::Rserve::Pooler.new(10, EM::Rserve::FiberedConnection, backend)
  end

  def plot(template, system=:erb)
    pool.r do |r|
      @path = File.join(Dir.pwd, "plots", "plot-#{request.object_id}.png")
      r[:color] = 'blue' #sets color variable in R context (used in the template)
      script = send system, template
      r.call(script, true) 
      ctype = content_type || 'image/png'
      File.open(@path,'r') do |ret|
        env["async.callback"].call [200, {'Content-Type' => ctype}, ret]
      end
      FileUtils.rm @path
    end
    throw :async
  end
end

get '/plot' do
  plot :plot, :erb
end

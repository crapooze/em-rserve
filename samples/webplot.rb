
$LOAD_PATH << './lib'
require 'sinatra'
require 'em-rserve'
require 'em-rserve/pooler'
require 'fileutils'

FileUtils.mkdir_p 'plots'

get '/' do
  redirect :plot
end

get '/plot' do
  EM::Rserve::Pooler::r do |r|
    @path = File.join(Dir.pwd, "plots", "plot-#{request.object_id}.png")
    script = erb :plot
    r.call(script, true) 
    File.open(@path,'r') do |ret|
      env["async.callback"].call [200, {'Content-Type' => 'image/png'}, ret]
    end
    FileUtils.rm @path
  end
  throw :async
end

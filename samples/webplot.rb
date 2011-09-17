
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
  def plot(template, system=:erb)
    EM::Rserve::Pooler::r do |r|
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

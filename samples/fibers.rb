$LOAD_PATH << './lib'
require 'em-rserve'
require 'em-rserve/pooler'

class MyConnection < EM::Rserve::FiberedConnection
  def ready
    p 'ready'
    super
  end
end

pool = EM::Rserve::Pooler.new(3, MyConnection)

EM::run do
  pool.fill

  EM.next_tick do
    EM::Rserve::Pooler::r do |r|
      x = (0 .. 5).map{|v| Math.sin(v)}
      y = x.map{|i| i**2 + 0.4*rand()}
      r[:dat] = {x: x, y: y}
      p r.call('cor(dat$x, dat$y)')
    end
  end

  EM.add_periodic_timer(1) do
    pool.r do |r|
      r[:dat] = 'hello world'
      p r[:dat]
    end
  end
end

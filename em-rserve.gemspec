# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "em-rserve/version"

Gem::Specification.new do |s|
  s.name        = "em-rserve"
  s.version     = EM::Rserve::VERSION
  s.authors     = ["crapooze"]
  s.email       = ["crapooze@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{An EventMachine client for RServe}
  s.description = %q{Do evented stats with EventMachine and RServe}

  s.rubyforge_project = "em-rserve"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

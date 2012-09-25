# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require "recipes0/version"

Gem::Specification.new do |s|
  s.name = "capistrano-recipes0"
  s.version = Recipes0::Version
  s.authors = ["Alexey Illarionov"]
  s.email = ["littlesavage@rambler.ru"]
  s.homepage = ""
  s.summary = %q{Наши рецепты для капистраны}
  s.description = %q{Наши рецепты для капистраны}

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'rake'
  s.add_runtime_dependency 'capistrano', '>=2.0.0'

end

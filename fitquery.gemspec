# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fitquery/version'

Gem::Specification.new do |spec|
  spec.name          = "fitquery"
  spec.version       = Fitquery::VERSION
  spec.authors       = ["Tony Peguero"]
  spec.email         = ["tony.peguero@payglobal.com"]
  spec.summary       = %q{Tools for inspecting and querying a FitNesse test hierarchy}
  spec.homepage      = "https://github.com/Plasmadog/fitquery"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end

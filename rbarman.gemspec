# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rbarman/version'

Gem::Specification.new do |spec|
  spec.name          = "rbarman"
  spec.version       = RBarman::VERSION
  spec.authors       = ["Holger Amann"]
  spec.email         = ["holger@sauspiel.de"]
  spec.description   = %q{Wrapper for 2ndQuadrant's PostgreSQL backup tool 'barman'}
  spec.summary       = %q{Wrapper for 2ndQuadrant's PostgreSQL backup tool 'barman'}
  spec.homepage      = "https://github.com/sauspiel/rbarman"
  spec.license       = "MIT"

  spec.files         = Dir['lib/**/*.rb', 'LICENSE.txt', 'README.md']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14.0"
  spec.add_dependency "mixlib-shellout", "~> 1.3.0"
end

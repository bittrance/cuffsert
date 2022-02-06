require File.expand_path('../lib/cuffsert/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name        = 'cuffsert'
  spec.version     = CuffSert::VERSION
  spec.summary     = 'Cuffsert provides a quick up-arrow-enter loading of a CloudFormation stack with good feedback'
  spec.description = 'Cuffsert allows encoding the metadata and commandline arguments needed to load a template in a versionable file which takes CloudFormation the last mile to really become an infrastructure-as-code platform.'
  spec.authors     = ['Anders Qvist']
  spec.email       = 'quest@lysator.liu.se'
  spec.homepage    = 'https://github.com/bittrance/cuffsert'
  spec.license     = 'MIT'

  spec.executables = ['cuffsert', 'cuffup', 'cuffdown']
  spec.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(/^spec/) }

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_runtime_dependency 'aws-sdk-cloudformation', '~> 1.3.0'
  spec.add_runtime_dependency 'aws-sdk-s3', '~> 1.8.0'
  spec.add_runtime_dependency 'colorize'
  spec.add_runtime_dependency 'hashdiff', '~> 1.0'
  spec.add_runtime_dependency 'nokogiri'
  spec.add_runtime_dependency 'ruby-termios'
  spec.add_runtime_dependency 'rx'
  spec.add_runtime_dependency 'webrick'

  spec.add_development_dependency 'bundler', '>= 1.12'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rx-rspec', '~> 0.4.3'
  spec.add_development_dependency 'simplecov'
end

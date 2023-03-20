require_relative './lib/version.rb'
Gem::Specification.new do |s|
  s.name        = "cloud_storage_interface"
  s.version     = CloudStorageInterface::VERSION
  s.date        = "2019-09-06"
  s.summary     = "provides a single interface for working with multiple cloud storage adapters (currently, AWS/S3 and GCP/GCS)"
  s.description = ""
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["edcast"]
  s.email       = 'mp@edcast.com'
  s.required_ruby_version = '~> 2.3'
  s.homepage    = "http://rubygems.org/gems/cloud_storage_interface"
  s.files       = Dir["lib/**/*.rb", "bin/*", "**/*.md", "LICENSE"]
  s.require_path = 'lib'
  s.required_rubygems_version = ">= 2.7.6"
  s.executables = Dir["bin/*"].map &File.method(:basename)
  s.add_dependency('aws-sdk', '~> 2')
  s.add_dependency('google-cloud-storage', '~> 0.24.0')
  s.add_dependency('activesupport', '~> 4.2.8')
  s.add_development_dependency('mocha', '~> 1.0.0')
  s.add_development_dependency('byebug', '~> 11.0.1')
  s.license     = 'MIT'
end

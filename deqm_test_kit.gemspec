# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'deqm_test_kit'
  spec.version       = '0.0.1'
  spec.authors       = ['Michael O\'Keefe', 'Elsa Perelli']
  spec.email         = ['tacoma-fhir-prototyping@groups.mitre.org']
  spec.summary       = 'A set of tests for DEQM\'s operations and resources'
  spec.description   = 'A set of tests for DEQM\'s operations and resources'
  spec.homepage      = 'https://github.com/projecttacoma/deqm-test-kit'
  spec.license       = 'Apache-2.0'
  spec.add_runtime_dependency 'inferno_core', '~> 0.5.1'
  spec.add_development_dependency 'database_cleaner-sequel', '~> 1.8'
  spec.add_development_dependency 'factory_bot', '~> 6.1'
  spec.add_development_dependency 'rspec', '~> 3.10'
  spec.add_development_dependency 'rubocop', '~> 1.18'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.4'
  spec.add_development_dependency 'webmock', '~> 3.11'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1.2')
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/projecttacoma/deqm-test-kit'
  spec.files = [
    Dir['lib/**/*.rb'],
    Dir['lib/**/*.json'],
    'LICENSE'
  ].flatten

  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
end

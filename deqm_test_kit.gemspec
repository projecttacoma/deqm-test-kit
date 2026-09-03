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
  spec.add_dependency 'inferno_core', '~> 1.1.2'
  # v0.6.x is the last SMART App Launch kit compatible with Inferno Core 1.1.
  # It provides reusable SMART STU2 discovery and standalone-launch groups.
  spec.add_dependency 'smart_app_launch_test_kit', '~> 0.6.4'
  spec.add_dependency 'sidekiq', '~> 7.2.4'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.3.6')
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

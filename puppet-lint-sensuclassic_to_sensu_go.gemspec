# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = 'puppet-lint-sensuclassic_to_sensu_go'
  spec.version     = '0.0.1'
  spec.homepage    = 'https://github.com/ghoneycutt/puppet-lint-empty_trailing_lines'
  spec.license     = 'Apache-2.0'
  spec.author      = 'Tailored Automation'
  spec.email       = 'code@tailoredautomation.io'
  spec.files       = Dir[
    'README.md',
    'LICENSE',
    'lib/**/*',
    'spec/**/*',
  ]
  spec.test_files  = Dir['spec/**/*']
  spec.summary     = 'puppet-lint sensuclassic_to_sensu_go check'
  spec.description = <<-EOF
    Converts sensuclassic to sensu-go manifests
  EOF

  spec.add_dependency             'puppet-lint', '>= 2.0', '< 3.0'
  spec.add_development_dependency 'rake', '>= 13.0', '< 14.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-collection_matchers', '~> 1.0'
  spec.add_development_dependency 'rspec-its', '~> 1.0'
  spec.add_development_dependency 'rubocop-rspec', '>= 1.0', '< 2.0'
  spec.add_development_dependency 'simplecov', '>= 0.17.1', '< 2.0'
end

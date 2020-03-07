require 'puppet-lint'

PuppetLint::Plugins.load_spec_helper

def read_fixture(name)
  fixtures_dir = File.join(File.dirname(__FILE__), 'fixtures')
  File.read(File.join(fixtures_dir, name))
end

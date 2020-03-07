class test {

  file { '/foo':
    ensure => 'present',
  }

  sensuclassic::check { 'check_cpu':
    ensure   => present,
    command  => '/opt/sensu/embedded/bin/check-cpu.rb',
    type       => 'foo',
    standalone => true,
    custom   => {
      'foo' => 'bar',
    },
  }
}

class test {

  file { '/foo':
    ensure => 'present',
  }

  sensu_check { 'check_cpu':
    ensure   => present,
    command  => '/opt/sensu/embedded/bin/check-cpu.rb',
    labels   => {
      'foo' => 'bar',
    },
  }
}

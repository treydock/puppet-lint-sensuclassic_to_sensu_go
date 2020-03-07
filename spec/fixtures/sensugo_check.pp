class test {

  file { '/foo':
    ensure => 'present',
  }

  sensu_check { 'check_cpu':
    ensure              => present,
    command             => '/opt/sensu/embedded/bin/check-cpu.rb',
    labels              => {
      'contacts' => 'foo@bar, foo@baz',
      'foo' => 'bar',
    },
    handlers            => ['foo','bar'],
    cron                => '0 0 * * *',
    interval            => 60,
    subscribers         => ['base','linux'],
    low_flap_threshold  => 0,
    high_flap_threshold => 0,
    timeout             => 10,
    publish             => true,
    ttl                 => 20,
    subdue              => undef,
#    proxy_requests      => 
#    hooks               => 
  }
}

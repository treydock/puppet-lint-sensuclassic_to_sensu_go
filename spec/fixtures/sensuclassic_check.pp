class test {

  file { '/foo':
    ensure => 'present',
  }

  sensuclassic::check { 'check_cpu':
    ensure              => present,
    command             => '/opt/sensu/embedded/bin/check-cpu.rb',
    type                => 'foo',
    standalone          => true,
    contacts            => ['foo@bar','foo@baz'],
    custom              => {
      'foo' => 'bar',
    },
    handlers            => ['foo','bar'],
    cron                => '0 0 * * *',
    interval            => 60,
    occurrences         => 2,
    refresh             => 20,
    source              => '/dne',
    subscribers         => ['base','linux'],
    low_flap_threshold  => 0,
    high_flap_threshold => 0,
    timeout             => 10,
    aggregate           => 'foo',
    aggregates          => ['foo'],
    handle              => false,
    publish             => true,
    dependencies        => ['foo'],
    content             => {},
    ttl                 => 20,
    ttl_status          => 0,
    auto_resolve        => false,
    subdue              => undef,
#    proxy_requests      => 
#    hooks               => 
  }
}

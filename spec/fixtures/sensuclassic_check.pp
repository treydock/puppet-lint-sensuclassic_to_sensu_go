class test {

  file { '/foo':
    ensure => 'present',
  }

  $contact = 'foo'

  sensuclassic::check { 'check_cpu':
    ensure              => present,
    command             => '/opt/sensu/embedded/bin/check-cpu.rb',
    type                => 'foo',
    standalone          => true,
    contacts            => ['foo@bar','foo@baz', $contact, "${contact}@domain"],
    custom              => {
      'foo' => 'bar',
      'bar' => $baz,
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

  sensuclassic::check { 'check_mem':
    ensure   => present,
    command  => '/opt/sensu/embedded/bin/check-memory.rb',
    contacts => ['foo@bar','foo@baz', $contact, "${contact}@domain"],
  }

  sensuclassic::check { 'check_disk_usage':
    command => 'check-disk-usage.rb -w :::disk.warning|80::: -c :::disk.critical|90:::',
  }

  sensuclassic::check { 'proxy':
    ensure         => 'present',
    command        => 'foo',
    proxy_requests => {
      'client_attributes' => {
        'device_type' => 'router',
      },
      'splay'             => false,
      'splay_coverage'    => 90,
    },
  }
}

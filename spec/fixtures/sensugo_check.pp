class test {

  file { '/foo':
    ensure => 'present',
  }

  $contact = 'foo'

  sensu_check { 'check_cpu':
    ensure              => present,
    command             => '/opt/sensu/embedded/bin/check-cpu.rb',
    labels              => {
      'contacts' => "foo@bar, foo@baz, ${contact}, ${contact}@domain",
      'foo' => 'bar',
      'bar' => $baz,
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
    annotations => {
      'fatigue_check/occurrences' => 2,
    },
  }

  sensu_check { 'check_mem':
    ensure   => present,
    command  => '/opt/sensu/embedded/bin/check-memory.rb',
    labels => {
      'contacts' => "foo@bar, foo@baz, ${contact}, ${contact}@domain",
    },
  }

  sensu_check { 'check_disk_usage':
    command => 'check-disk-usage.rb -w {{disk.warning | default 80}} -c {{disk.critical | default 90}}',
  }

  sensu_check { 'proxy':
    ensure         => 'present',
    command        => 'foo',
    proxy_requests => {
      'entity_attributes' => [
        "entity.labels.device_type == 'router'",
      ],
      'splay'             => false,
      'splay_coverage'    => 90,
    },
  }
}

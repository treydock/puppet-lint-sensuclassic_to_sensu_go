class test {

  file { '/foo':
    ensure => 'present',
  }

  $contact = 'foo'

  sensu_check { 'check_mem_type':
    ensure   => present,
    command  => '/opt/sensu/embedded/bin/check-memory.rb',
  }

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
    proxy_entity_name   => 'entity',
    subscriptions       => ['base','linux'],
    low_flap_threshold  => 0,
    high_flap_threshold => 0,
    timeout             => 10,
    publish             => true,
    ttl                 => 20,
    subdue              => undef,
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

  sensu_check { 'check_cpu_hook':
    ensure  => present,
    command => '/opt/sensu/embedded/bin/check-cpu.rb',
    check_hooks   => [
      { 'non-zero' => ['non-zero-check_cpu_hook'] },
    ],
  }

  sensu_hook { 'non-zero-check_cpu_hook':
    ensure  => 'present',
    command => 'ps aux',
    timeout => 10,
    stdin   => false,
  }

  sensu_check { 'check_mem_hook':
    ensure  => present,
    command => '/opt/sensu/embedded/bin/check-memory.rb',
    check_hooks   => [
      { 'non-zero' => ['non-zero-check_mem_hook'] },
      { 'unknown' => ['unknown-check_mem_hook'] },
    ],
  }

  sensu_hook { 'non-zero-check_mem_hook':
    ensure  => 'present',
    command => 'ps aux',
    timeout => 10,
    stdin   => false,
  }

  sensu_hook { 'unknown-check_mem_hook':
    ensure  => 'present',
    command => '/dne',
    timeout => 5,
    stdin   => true,
  }
}

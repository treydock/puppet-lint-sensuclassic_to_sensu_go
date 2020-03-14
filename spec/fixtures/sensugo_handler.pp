class test {
  file { '/dne':
    ensure => 'present',
  }

  sensu_handler { 'mail':
    ensure => 'present',
    type       => 'pipe',
    command    => "mailx -s 'sensu event' example@address.com",
  }

  sensu_handler { 'mail2':
    ensure => 'present',
    type       => 'pipe',
    command    => "mailx -s 'sensu event' example@address.com",
  }

  sensu_handler { 'test-filters':
    ensure => 'present',
    type            => 'pipe',
    command         => 'command',
    filters         => ['fatigue_check', 'foo'],
  }

  sensu_handler { 'test-filters2':
    ensure => 'present',
    type            => 'pipe',
    command         => 'command',
    filters         => ['fatigue_check', 'foo'],
  }

  sensu_handler { 'test-filters3':
    ensure => 'present',
    type            => 'pipe',
    command         => 'command',
    filters         => ['fatigue_check', 'foo'],
  }

  sensu_handler { 'test-filter':
    ensure => 'present',
    type    => 'pipe',
    command => 'command',
    filters => ['fatigue_check'],
  }

  sensu_handler { 'test-filter2':
    ensure => 'present',
    type    => 'pipe',
    command => 'command',
    filters => ['foo', 'fatigue_check'],
  }

  sensu_handler { 'test-transport':
    ensure => 'present',
    type  => 'transport',
    pipe  => { 'type' => 'direct', 'name' => 'example_handler_queue' },
  }
}

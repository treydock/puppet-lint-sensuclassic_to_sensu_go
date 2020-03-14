class test {
  file { '/dne':
    ensure => 'present',
  }

  sensuclassic::handler { 'mail':
    type       => 'pipe',
    command    => "mailx -s 'sensu event' example@address.com",
    severities => ['critical', 'unknown'],
    handle_flapping => true,
  }

  sensuclassic_handler { 'mail2':
    type       => 'pipe',
    command    => "mailx -s 'sensu event' example@address.com",
  }

  sensuclassic::handler { 'test-filters':
    type            => 'pipe',
    command         => 'command',
    handle_silenced => false,
    filters         => ['occurrences', 'check_dependencies', 'foo'],
  }

  sensuclassic::handler { 'test-filters2':
    type            => 'pipe',
    command         => 'command',
    handle_silenced => false,
    filters         => ['check_dependencies', 'occurrences', 'foo'],
  }

  sensuclassic::handler { 'test-filters3':
    type            => 'pipe',
    command         => 'command',
    handle_silenced => false,
    filters         => ['occurrences', 'foo', 'check_dependencies'],
  }

  sensuclassic::handler { 'test-filter':
    type    => 'pipe',
    command => 'command',
    filter  => 'occurrences',
  }

  sensuclassic::handler { 'test-filter2':
    type    => 'pipe',
    command => 'command',
    filter  => 'occurrences',
    filters => ['foo'],
  }

  sensuclassic::handler { 'test-transport':
    type  => 'transport',
    pipe  => { 'type' => 'direct', 'name' => 'example_handler_queue' },
  }

  sensuclassic::handler { 'test-amqp':
    type     => 'amqp',
    exchange => {'foo' => 'bar'},
  }
}

class test {
  sensu_check { 'check_cpu':
    ensure              => present,
    command             => '/opt/sensu/embedded/bin/check-cpu.rb',
    labels              => {
      'contacts' => "foo@bar, foo@baz, ${contact}, ${contact}@domain",
      'foo' => '1',
      'bar' => 'true',
    },
    annotations => {
      'fatigue_check/interval' => '20',
      'fatigue_check/occurrences' => '2',
    },
  }
}

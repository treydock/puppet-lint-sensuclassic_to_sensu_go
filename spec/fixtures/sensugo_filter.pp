class test {
  file { '/dne':
    ensure => 'present',
  }

  sensuclassic::filter { 'test1':
    negate     => false,
    attributes => {
      'client' => {
        'environment' => 'production',
      },
    }
  }

  sensuclassic_filter { 'test2':
    negate     => false,
    attributes => {
      'client' => {
        'environment' => 'dev',
      },
    }
  }
}

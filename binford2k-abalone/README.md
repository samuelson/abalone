# abalone
A Puppet module for managing Abalone, a simple Sinatra & hterm based web terminal.

#### Table of Contents

1. [Overview](#overview)
1. [Usage](#usage)
    1. [Parameters](#parameters)
    1. [Custom Parameters](#custom-parameters)
1. [Limitations](#limitations)

## Overview

Abalone imply exposes a login shell to a web browser. This can be the Unix standard
`/bin/login` using a system user account, a custom command, or an SSH frontend.

See [the Abalone project page for more information](https://github.com/binford2k/abalone).

## Usage

The simplest use case is to just include the class and accept all the defaults:

```puppet
include abalone
```

### Parameters

You can customize the configuration by passing in several parameters.

See [documentation](https://github.com/binford2k/abalone#configuration) on the Abalone
project page to see what these options do and what values they can take. 

* `$port`
* `$bind`
* `$method`
* `$bannerfile`
* `$logfile`
* `$ssh_host`
* `$ssh_cert`
* `$ssh_port`
* `$ssh_user`
* `$command`
* `$params` (see below)

### Custom Parameters

Options for a custom command can be configured by either whitelisting options in an
array, or providing a full list of options and values in a hash.

#### Simple Options

List allowed options in an Array:

```puppet
class { 'abalone':
  command => '/usr/local/bin/run-container',
  params  => [ 'username', 'image' ],
}
```
[Documentation](https://github.com/binford2k/abalone#simple-options)

#### Customized options

With a Hash you can fully customize the options which may be passed in, including
remapping them to command line arguments and filtering accepted values:

```puppet
class { 'abalone':
  command => '/usr/local/bin/run-container',
  params  => {
    'username' => undef,
    'type'     => ['demo', 'testing'],
    'image'    => {
      'map'    => '--create-image',
      'values' => [ 'ubuntu', 'rhel', '/centos[5,6,7]/' ],
    },
  },
}
```

[Documentation](https://github.com/binford2k/abalone#customized-options)

## Limitations

This is still early in development.

## Disclaimer

I take no liability for the use of this tool.

Contact
-------

binford2k@gmail.com

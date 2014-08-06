# ============================================================================
package App::HomelyAlarm::Role::Server;
# ============================================================================
use utf8;

use namespace::autoclean;
use MooseX::App::Role;

option 'port' => (
    is              => 'rw',
    isa             => 'Int',
    documentation   => 'Listening port',
    default         => 1222,
);

option 'host' => (
    is              => 'rw',
    isa             => 'Str',
    documentation   => 'Bind host',
    default         => 'localhost',
);

option 'secret' => (
    is              => 'rw',
    isa             => 'Str',
    documentation   => 'Alarm server secret',
    required        => 1,
);

1;
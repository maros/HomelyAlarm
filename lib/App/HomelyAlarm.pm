package App::HomelyAlarm {
    use 5.014; 
    
    our $AUTHORITY = 'cpan:MAROS';
    our $VERSION = '1.00';
    
    use App::HomelyAlarm::Utils;
    
    use MooseX::App qw(Color Config);
    app_namespace 'App::HomelyAlarm::Command';
    app_strict(1);
    
    use App::HomelyAlarm::MessageLog;
    use App::HomelyAlarm::Recipient;
    use Sereal::Encoder qw(encode_sereal);
    use Sereal::Decoder qw(decode_sereal);
    
    option 'recipients_database' => (
        is              => 'ro',
        required        => 1,
        cmd_flag        => 'recipients',
        default         => $ENV{HOME}.'/.homely_alarm.db',
        isa             => 'Str',
        documentation   => q[Recipients database file],
    );
    
    has 'recipients' => (
        is          => 'rw',
        lazy_build  => 1,
        traits      => ['Array'],
        handles     => {
            'add_recipient'     => 'push',
            'recipients_list'   => 'elements',
        }
    );
    
    sub _build_recipients {
        my ($self) = @_;
        my $file = Path::Class::File->new($self->recipients_database);
        return []
            unless -e $file;
        my $decoded = decode_sereal($file->slurp());
        return []
            unless ref($decoded) eq 'ARRAY';
        return $decoded;
    }
    
    sub write_recipients {
        my ($self) = @_;
        Path::Class::File
            ->new($self->recipients_database)
            ->spew(encode_sereal($self->recipients));
    }
    
    __PACKAGE__->meta->make_immutable;
}

1;

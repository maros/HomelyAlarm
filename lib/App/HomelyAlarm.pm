package App::HomelyAlarm {
    use 5.014; 
    
    our $AUTHORITY = 'cpan:MAROS';
    our $VERSION = '1.00';
    
    use App::HomelyAlarm::Utils;
    
    use MooseX::App qw(Color Config);
    app_namespace 'App::HomelyAlarm::Command';
    app_strict(1);
    
    use App::HomelyAlarm::Meta::Attribute::Filter;
    use App::HomelyAlarm::Meta::Attribute::Database;
    use App::HomelyAlarm::MessageLog;
    use App::HomelyAlarm::EventLog;
    use App::HomelyAlarm::Recipient;
    use App::HomelyAlarm::Storage;
    
    has 'storage' => (
        is              => 'ro',
        isa             => 'App::HomelyAlarm::Storage',
        lazy_build      => 1,
    );
    
    option 'database' => (
        is              => 'ro',
        required        => 1,
        cmd_flag        => 'recipients',
        default         => $ENV{HOME}.'/.homely_alarm.db',
        isa             => 'Str',
        documentation   => q[Database file],
    );
    
    sub _build_storage {
        my ($self) = @_;
        return App::HomelyAlarm::Storage->new( database => $self->database );
    }
    
    __PACKAGE__->meta->make_immutable;
}

1;

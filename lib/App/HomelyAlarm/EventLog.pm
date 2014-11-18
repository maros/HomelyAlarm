package App::HomelyAlarm::EventLog {
    use 5.014; 

    use Moose;
    with qw(App::HomelyAlarm::Role::Severity
        App::HomelyAlarm::Role::Database);
    
    has 'message' => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
        traits      => ['Filter','Database'],
    );
    
    has 'timestamp' => (
        is          => 'ro',
        isa         => 'Int',
        default     => sub { time },
        traits      => ['Filter','Database'],
    );
    
    has 'type' => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
        traits      => ['Filter','Database'],
    );
    
    has '+severity_level' => (
        required    => 1,
    );
    
    sub database_table {
        return 'event';
    }
    
    sub stringify {
        my ($self) = @_;
        # TODO
        return $self->timestamp;
    }
    
    __PACKAGE__->meta->make_immutable;
}

1;
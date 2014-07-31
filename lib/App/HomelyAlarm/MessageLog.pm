package App::HomelyAlarm::MessageLog {
    use 5.014; 

    use Moose;
    
    has 'message' => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
    );
    
    has 'timestamp' => (
        is          => 'ro',
        isa         => 'Int',
        default     => sub { time },
    );
    
    has 'mode' => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
    );
    
    has 'severity' => (
        is          => 'ro',
        isa         => 'App::HomelyAlarm::Type::Severity',
        required    => 1,
    );
    
    sub stringify {
        my ($self) = @_;
        return $self->timestamp;
    }
    
    __PACKAGE__->meta->make_immutable;
}

1;
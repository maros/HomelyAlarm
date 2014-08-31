package App::HomelyAlarm::MessageLog {
    use 5.014; 

    use Moose;
    with qw(App::HomelyAlarm::Role::Severity
        App::HomelyAlarm::Role::Database);
    
    has 'recipient' => (
        is          => 'ro',
        isa         => 'App::HomelyAlarm::Recipient',
        required    => 1,
        weak_ref    => 1,
    );
    
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
    
    has '+severity' => (
        required    => 1,
    );
    
    has 'reference' => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
    );
    
    has 'status' => (
        is          => 'rw',
        isa         => 'Int',
        default     => 0,
    );
    
    sub database_fields {
        return qw(message timestamp mode severity_level reference status recipient) # TODO introspection
    }
    
    sub database_table {
        return 'message';
    }
    
    sub stringify {
        my ($self) = @_;
        # TODO
        return $self->timestamp;
    }
    
    sub set_failed {
        my ($self,$storage) = @_;
        $self->status(1);
        $self->store($storage);
    }
    
    sub set_success {
        my ($self,$storage) = @_;
        $self->status(2);
        $self->store;
    }
    
    sub find_message {
        my ($class,$storage,$reference) = @_;
        
        my $sql = 'SELECT id,'.
            join(',',$class->database_fields).
            ' FROM '.
            $class->database_table.
            ' WHERE reference = ?';
        my $sth = $storage->dbh->prepare($sql);
        $sth->execute($reference);
        return $class->_inflate_object($storage,$sth->fetchrow_hashref());
    }
    
    sub last_message_recipient {
        my ($class,$storage,$recipient) = @_;
        
        my $sql = 'SELECT id,'.
            join(',',$class->database_fields).
            ' FROM '.
            $class->database_table.
            ' WHERE recipient = ? ORDER BY timestamp DESC LIMIT 1';
        my $sth = $storage->dbh->prepare($sql);
        $sth->execute($recipient);
        return $class->_inflate_object($storage,$sth->fetchrow_hashref());
    }
    
    sub ago {
        my ($self) = @_;
        return (time - $self->timestamp);
    }
    
    around '_inflate' => sub {
        my ($orig,$class,$storage,$hashref) = @_;
        
        my $return = $class->$orig($storage,$hashref);
        $return->{recipient} = App::HomelyAlarm::Recipient->get($storage,$return->{recipient});
        return $return;
    };
    
    __PACKAGE__->meta->make_immutable;
}

1;
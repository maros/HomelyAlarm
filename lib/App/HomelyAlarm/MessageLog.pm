package App::HomelyAlarm::MessageLog {
    use 5.014; 

    use Moose;
    with qw(App::HomelyAlarm::Role::Severity
        App::HomelyAlarm::Role::Database);
    
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
        isa         => 'Bool',
    );
    
    sub database_fields {
        return qw(message timestamp mode severity_level reference status) # TODO introspection
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
        $storage->dbh_do('UPDATE '.$self->database_table.' SET status = 1 WHERE id = ?',$self->database_id);
    }
    
    sub set_success {
        my ($self,$storage) = @_;
        $storage->dbh_do('UPDATE '.$self->database_table.' SET status = 2 WHERE id = ?',$self->database_id);
    }
    
    sub find_message {
        my ($class,$storage,$reference) = @_;
        
        my $sql = 'SELECT '.
            join(',',$class->database_fields).
            ' FROM '.
            $class->database_field.
            ' WHERE reference = ?';
        my $sth = $storage->dbh->prepare($sql);
        $sth->execute($reference);
        return $class->_inflate($sth->fetchrow_hashref());
    }
    
    sub last_message_recipient {
        my ($class,$storage,$recipient) = @_;
        
        my $sql = 'SELECT '.
            join(',',$class->database_fields).
            ' FROM '.
            $class->database_table.
            ' WHERE recipient = ? ORDER BY timestamp DESC LIMIT 1';
        my $sth = $storage->dbh->prepare($sql);
        $sth->execute($recipient);
        return $class->_inflate($sth->fetchrow_hashref());
    }
    
    __PACKAGE__->meta->make_immutable;
}

1;
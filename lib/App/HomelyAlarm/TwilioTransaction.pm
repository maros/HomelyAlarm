package App::HomelyAlarm::TwilioTransaction {
    use 5.014; 

    use Moose;
    
    our %INSTANCES;
    
    has 'sid' => (
        is      => 'rw',
        required=> 1,
    );
    
    has 'message' => (
        is      => 'rw',
        required=> 1,
    );
    
    has 'severity' => (
        is      => 'rw',
        isa     => 'App::HomelyAlarm::Type::Severity',
        default => 'high',
    );
    
    has 'time' => (
        is      => 'ro',
        default => sub {
            return time();
        }
    );
    
    has 'recipient' => (
        is      => 'ro',
        isa     => 'App::HomelyAlarm::Recipient',
        required=> 1,
        weak_ref=> 1,
    );
    
    sub BUILD {
        my ($self) = @_;
        $INSTANCES{$self->sid} = $self;
    }
    
    sub DEMOLISH {
        my ($self) = @_;
        delete $INSTANCES{$self->sid};
    }
    
    sub all_transactions {
        my ($class) = @_;
        return keys %INSTANCES;
    }
    
    sub get_transactions {
        my ($class,$sid) = @_;
        return $INSTANCES{$sid};
    }
    
    sub remove_transactions {
        my ($class,$sid) = @_;
        return delete $INSTANCES{$sid};
    }
    
    __PACKAGE__->meta->make_immutable;
};


1;
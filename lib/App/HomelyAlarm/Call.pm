package App::HomelyAlarm::Call {
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
    
    has 'time' => (
        is      => 'ro',
        default => sub {
            return time();
        }
    );
    
    has 'callee' => (
        is      => 'ro',
        required=> 1,
    );
    
    sub BUILD {
        my ($self) = @_;
        $INSTANCES{$self->sid} = $self;
    }
    
    sub DEMOLISH {
        my ($self) = @_;
        delete $INSTANCES{$self->sid};
    }
    
    sub all_calls {
        my ($class) = @_;
        return keys %INSTANCES;
    }
    
    sub get_call {
        my ($class,$sid) = @_;
        return $INSTANCES{$sid};
    }
    
    sub remove_call {
        my ($class,$sid) = @_;
        return delete $INSTANCES{$sid};
    }
    
    __PACKAGE__->meta->make_immutable;
};


1;
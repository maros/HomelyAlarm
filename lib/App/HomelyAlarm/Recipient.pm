package App::HomelyAlarm::Recipient {
    use 5.014; 

    use Moose;
    with qw(App::HomelyAlarm::Role::Recipient);
    
    use App::HomelyAlarm::MessageLog;
    
    has 'database_id' => (
        is              => 'rw',
        isa             => 'Int',
        predicate       => 'is_in_database',
    );
    
    sub store {
        my ($self) = @_;
        App::HomelyAlarm::Storage->instance->store_recipient($self);
    }
    
    sub remove {
        my ($self) = @_;
        App::HomelyAlarm::Storage->instance->remove_recipient($self);
    }
    
    sub add_message {
        my ($self,$message,$mode,$severity) = @_;
        
        # TODO
    }
#    
#    sub all_messages {
#        my ($self) = @_;
#        return sort { $a->timestamp <=> $b->timestamp }  @{$self->message_log};
#    }
#    
#    sub last_message {
#        my ($self) = @_;
#        return ($self->all_messages)[-1];
#    }
}

1;
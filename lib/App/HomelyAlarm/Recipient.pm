package App::HomelyAlarm::Recipient {
    use 5.014; 

    use Moose;
    with qw(App::HomelyAlarm::Role::Recipient
        App::HomelyAlarm::Role::Database);
        
    sub database_fields {
        return qw(telephone email only_call only_vacation severity_level) # TODO introspection
    }
    
    sub database_table {
        return 'recipient';
    }
    
    around 'remove' => sub {
        my ($orig,$self,$storage) = @_;
        
        $storage->dbh_do('DELETE FROM message WHERE recipient = ?',$self->database_id);
        
        return $self->$orig($storage);
    };
    
    sub add_message {
        my ($self,$storage,%params) = @_;
        
        App::HomelyAlarm::MessageLog
            ->new(
                recipient   => $self,
                (map { $_ => $params{$_} } qw(mode message severity reference))
            )
            ->store($storage);
    }
    
    sub last_message {
        my ($self,$storage) = @_;
        
        return App::HomelyAlarm::MessageLog->last_message_recipient($storage,$self->database_id);
    }
    
    sub message_log {
        my ($self,$storage) = @_;
        
        return App::HomelyAlarm::MessageLog->list($storage,{ recipient => $self->database_id });
    }
}

1;
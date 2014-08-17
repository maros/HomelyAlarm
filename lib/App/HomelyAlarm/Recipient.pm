package App::HomelyAlarm::Recipient {
    use 5.014; 

    use Moose;
    with qw(App::HomelyAlarm::Role::Recipient
        App::HomelyAlarm::Role::Database);
    
    use App::HomelyAlarm::MessageLog;
    
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
        
        $storage->dbh_do('INSERT INTO message 
            (recipient,mode,message,severity,reference)
            VALUES
            (?,?,?,?)',
            $self->database_id,
            $params{mode},
            $params{message},
            $params{severity},
            $params{reference},
        );
    }
    
    sub last_message {
        my ($self,$storage) = @_;
        
        return App::HomelyAlarm::MessageLog->last_message_recipient($storage,$self->database_id);
    }
}

1;
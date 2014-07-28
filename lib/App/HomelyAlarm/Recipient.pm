package App::HomelyAlarm::Recipient {
    use 5.014; 

    use Moose;
    with qw(App::HomelyAlarm::Role::Recipient);
    
    use App::HomelyAlarm::MessageLog;
    
    has 'message_log' => (
        default     => sub { [] },
        is          => 'rw',
    );
    
    sub add_message {
        my ($self,$message,$mode) = @_;
        
        my $message_log = App::HomelyAlarm::MessageLog->new(
            message     => $message,
            mode        => $mode,
        );
        
        push(@{$self->message_log},$message_log);
    }
    
    sub all_messages {
        my ($self) = @_;
        return sort { $a->timestamp <=> $b->timestamp }  @{$self->message_log};
    }
    
    sub last_message {
        my ($self) = @_;
        return ($self->all_messages)[-1];
    }
}

1;
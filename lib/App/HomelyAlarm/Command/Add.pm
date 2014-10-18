package App::HomelyAlarm::Command::Add {
    use 5.014;
    
    use App::HomelyAlarm;
    use MooseX::App::Command;
    extends qw(App::HomelyAlarm);
    with qw(App::HomelyAlarm::Role::Recipient);
    
    option '+telephone' => ();
    option '+email' => ();
    option '+only_vacation' => ( default => 0 );
    option '+only_call' => ( default => 0 );
    option '+severity_level' => ( cmd_flag => 'severity' );
    
    sub _error {
        my ($self,$message) = @_;
        
        print MooseX::App::Message::Envelope->new(
            $self->meta->command_message(
                header          => $message,
                type            => "error",
            )
        )->stringify;
    }
    
    sub run {
        my ($self) = @_;
        $self->format();
        
        unless ($self->has_telephone || $self->has_email) {
            return $self->_error("Need to set either email or telephone number");
        }
        
        if ($self->only_call && ! $self->has_telephone) {
            return $self->_error("Cannot set --only_call flag without telephone number");
        }
        
        if ($self->has_email && 
            App::HomelyAlarm::Recipient->count($self->storage,{ email => $self->email })) {
            return $self->_error("Duplicate e-mail address: ".$self->email);
        }
        
        if ($self->has_telephone && 
            App::HomelyAlarm::Recipient->count($self->storage,{ telephone => $self->telephone })) {
            return $self->_error("Duplicate telephone number: ".$self->telephone);
        }
        
        my $new_recipient = App::HomelyAlarm::Recipient->new(
            map { $_ => $self->$_ } 
            grep { defined $self->$_ } 
            qw(telephone email only_vacation only_call severity) # TODO introspection
        );
        
        say "Adding recipient ".$new_recipient->stringify;
        $new_recipient->store($self->storage);
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::Add - Add a recipient

=cut
}

1;
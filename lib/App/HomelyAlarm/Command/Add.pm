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
    option '+severity' => ();
    
    sub run {
        my ($self) = @_;
        $self->format();
        
        unless ($self->has_telephone || $self->has_email) {
            say "Need to set either email or telephone number";
            return;
        }
        
        if ($self->only_call && ! $self->has_telephone) {
            say "Cannot set --only_call flag without telephone number";
            return;
        }
        
        if ($self->has_email && 
            App::HomelyAlarm::Recipient->count($self->storage,{ email => $self->email })) {
            say "Duplicate e-mail address: ".$self->email;
            return;
        }
        
        if ($self->has_telephone && 
            App::HomelyAlarm::Recipient->count($self->storage,{ telephone => $self->telephone })) {
            say "Duplicate telephone number: ".$self->telephone;
            return;
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
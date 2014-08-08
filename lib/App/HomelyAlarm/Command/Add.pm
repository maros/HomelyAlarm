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
        
        foreach my $recipient ($self->recipients_list) {
            if ($self->compare_email($recipient) == 1) {
                say "Duplicate e-mail address: ".$self->email;
                return;
            }
            if ($self->compare_telephone($recipient) == 1) {
                say "Duplicate telephone number: ".$self->telephone;
                return;
            }
        }
        
        my $new_recipient = App::HomelyAlarm::Recipient->new(%{$self});
        say "Adding recipient ".$new_recipient->stringify;
        $self->add_recipient($new_recipient);
        $self->write_recipients;
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::Add - Add a recipient

=cut
}

1;
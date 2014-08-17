package App::HomelyAlarm::Command::Remove {
    use 5.014;
    
    use App::HomelyAlarm;
    use MooseX::App::Command;
    extends qw(App::HomelyAlarm);
    with qw(App::HomelyAlarm::Role::Recipient);
    
    option '+telephone' => ();
    option '+email' => ();
    option '+only_vacation' => ();
    option '+only_call' => ();
    option '+severity' => ();
    
    sub run {
        my ($self) = @_;
        $self->format();
        
        my $total = $self->recipients_count();
        my $found = 0;
        
        foreach my $recipient ($self->recipients_list()) {
            # TODO confirm?
            $found++;
            say "Removing recipient ".$recipient->stringify;
            $recipient->remove($self->storage);
        }
        say "Removed $found out of $total recipients";
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::Remove - Remove recipient from the list

=cut
}

1;
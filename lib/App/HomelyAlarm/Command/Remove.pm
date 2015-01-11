package App::HomelyAlarm::Command::Remove {
    use 5.014;
    
    use App::HomelyAlarm;
    use MooseX::App::Command;
    extends qw(App::HomelyAlarm);
    with qw(App::HomelyAlarm::Role::Recipient
        App::HomelyAlarm::Role::Filter);
    
    option '+telephone' => ();
    option '+email' => ();
    option '+only_vacation' => ();
    option '+only_call' => ();
    option '+severity_level' => ( cmd_flag => 'severity' );
    
    sub run {
        my ($self) = @_;
        $self->format();
        my %filter  = $self->for_filter;
        my $total   = App::HomelyAlarm::Recipient->count($self->storage);
        my $found   = 0;
        
        foreach my $recipient (App::HomelyAlarm::Recipient->list($self->storage,\%filter)) {
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
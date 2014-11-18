package App::HomelyAlarm::Command::Event {
    use 5.014;
    
    use App::HomelyAlarm;
    use MooseX::App::Command;
    extends qw(App::HomelyAlarm);
    with qw(App::HomelyAlarm::Role::Severity
        App::HomelyAlarm::Role::Filter);
    
    option '+severity_level' => ( cmd_flag => 'severity' );
    
    sub run {
        my ($self) = @_;
        
        my %filter  = $self->for_filter;
        my $total   = App::HomelyAlarm::EventLog->count($self->storage);
        my $found   = 0;
        
        foreach my $event (App::HomelyAlarm::EventLog->list($self->storage,\%filter)) {
            $found++;
            say $event->stringify;
        }
        if ($found) {
            say "-" x $MooseX::App::Utils::SCREEN_WIDTH;
        }
        say "Found $found out of $total events";
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::Event - Show all events

=cut
}

1;
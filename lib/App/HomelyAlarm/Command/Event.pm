package App::HomelyAlarm::Command::Event {
    use 5.014;
    
    use App::HomelyAlarm;
    use MooseX::App::Command;
    extends qw(App::HomelyAlarm);
    with qw(App::HomelyAlarm::Role::Severity);
    
    option '+severity_level' => ( cmd_flag => 'severity' );
    
    sub run {
        my ($self) = @_;
        $self->format();
        
        my %filter  = $self->for_filter;
        my $total   = App::HomelyAlarm::Event->count($self->storage);
        my $found   = 0;
        
        foreach my $recipient (App::HomelyAlarm::Event->list($self->storage,\%filter)) {
            $found++;
            say $recipient->stringify;
#            my $last_message = $recipient->last_message($self->storage);
#            if (defined $last_message) {
#                say MooseX::App::Utils::format_list([$last_message->stringify]);
#            } else {
#                say MooseX::App::Utils::format_list(["Not contacted before"]);
#            }
#            
#            say "-" x $MooseX::App::Utils::SCREEN_WIDTH;
        }
        say "Found $found out of $total events";
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::Event - Show all events

=cut
}

1;
package App::HomelyAlarm::Command::List {
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
    
    sub run {
        my ($self) = @_;
        $self->format();
        
        my %filter  = $self->for_filter;
        my $total   = App::HomelyAlarm::Recipient->count($self->storage);
        my $found   = 0;
        
        foreach my $recipient (App::HomelyAlarm::Recipient->list($self->storage,\%filter)) {
            $found++;
            say $recipient->stringify;
        }
        if ($found) {
            say "-" x $MooseX::App::Utils::SCREEN_WIDTH;
        }
        say "Found $found out of $total recipients";
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::List - Show all recipients

=cut
}

1;
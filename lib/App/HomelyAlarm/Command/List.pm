package App::HomelyAlarm::Command::List {
    use 5.014;
    
    use MooseX::App::Command;
    extends qw(App::HomelyAlarm);
    with qw(App::HomelyAlarm::Role::Recipient);
    
    option '+telephone' => ();
    option '+email' => ();
    option '+only_vacation' => ();
    option '+only_call' => ();
    
    sub run {
        my ($self) = @_;
        $self->format();
        
        my ($total,$found) = (0,0);
        foreach my $recipient ($self->recipients_list) {
            $total++;
            next
                unless $self->compare_all($recipient);
            $found++;
            say $recipient->stringify;
            say 
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
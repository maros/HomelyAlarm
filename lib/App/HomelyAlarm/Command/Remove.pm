package App::HomelyAlarm::Command::Remove {
    use 5.014;
    
    use MooseX::App::Command;
    extends qw(App::HomelyAlarm);
    with qw(App::HomelyAlarm::Role::Recipient);
    
    option '+telephone' => ();
    option '+email' => ();
    option '+only_vacation' => ( default => 0 );
    
    sub run {
        # TODO Run add recipient
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::Remove - Remove recipient from the list

=cut
}

1;
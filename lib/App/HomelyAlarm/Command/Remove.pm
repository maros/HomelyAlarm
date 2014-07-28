package App::HomelyAlarm::Command::Remove {
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
        
        my @new_recipients;
        my ($total,$found) = (0,0);
        foreach my $recipient ($self->recipients_list) {
            $total++;
            if ($self->compare_all($recipient)) {
                say "Removing recipient ".$recipient->stringify;
                $found++;
                next;
            }
            push(@new_recipients,$recipient);
        }
        say "Removed $found out of $total recipients";
        
        $self->recipients(\@new_recipients);
        $self->write_recipients;
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::Remove - Remove recipient from the list

=cut
}

1;
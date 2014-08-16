package App::HomelyAlarm::Command::List {
    use 5.014;
    
    use App::HomelyAlarm;
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
        
        my $total = $self->recipients_count();
        my $found = 0;
        
        foreach my $recipient ($self->recipients_list()) {
            $found++;
            say $recipient->stringify;
#            my $last_message = $recipient->last_message;
#            if (defined $last_message) {
#                say MooseX::App::Utils::format_list([$last_message->stringify]);
#            } else {
#                say MooseX::App::Utils::format_list(["Not contacted before"]);
#            }
#            
#            say "-" x $MooseX::App::Utils::SCREEN_WIDTH;
        }
        say "Found $found out of $total recipients";
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::List - Show all recipients

=cut
}

1;
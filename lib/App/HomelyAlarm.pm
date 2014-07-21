package App::HomelyAlarm {
    use 5.014; 
    
    our $AUTHORITY = 'cpan:MAROS';
    our $VERSION = '1.00';
    
    use MooseX::App qw(Color Config);
    app_namespace 'App::HomelyAlarm::Command';
    
    use App::HomelyAlarm::Recipient;
    
    __PACKAGE__->meta->make_immutable;
}

1;

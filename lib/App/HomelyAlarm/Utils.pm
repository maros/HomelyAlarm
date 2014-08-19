package App::HomelyAlarm::Utils {
    use 5.014;
    use warnings;
    
    our @SEVERITY = qw(low medium high);
    
    use Moose::Util::TypeConstraints;
    
    subtype 'App::HomelyAlarm::Type::Email',
        as 'Str',
        where { m/^[[:alnum:].-]+\@[[:alnum:].-]+$/ },
        message { 'Not a valid e-mail address' };
    
    subtype 'App::HomelyAlarm::Type::Telephone',
        as 'Str',
        where { m/^(00|\+)\d+$/ },
        message { 'Not a valid telephone number (needs to begin with intl. prefix)' };
    
    subtype 'App::HomelyAlarm::Type::Severity',
        as enum(\@SEVERITY);
    
    no Moose::Util::TypeConstraints;
    
    sub severity_level {
        my ($severity) = @_;
        return
            unless $severity;
        my $level = 0;
        foreach (@SEVERITY) {
            $level++;
            return $level 
                if ($_ eq $severity);
        }
        return;
    }
    
    sub severity_name {
        my ($severity) = @_;
        return
            unless $severity;
        my $level = 0;
        foreach (@SEVERITY) {
            $level++;
            return $_ 
                if ($severity == $level);
        }
        return;
    }
}

1;
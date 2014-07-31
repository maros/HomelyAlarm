package App::HomelyAlarm::Utils {
    use 5.014;
    use warnings;
    
    our @SEVERITY = qw(low medium high);
    
    use Moose::Util::TypeConstraints;
    
    subtype 'App::HomelyAlarm::Type::Severity',
        as enum(\@SEVERITY);
    
    no Moose::Util::TypeConstraints;
    
    sub severity_level {
        my ($severity) = @_;
        my $level = 0;
        foreach (@SEVERITY) {
            $level++;
            return $level 
                if ($_ eq $severity);
        }
        return;
    }
    
}

1;
package App::HomelyAlarm::Role::Severity {
    
    use Moose::Role;
    
    has 'severity' => (
        is              => 'rw',
        isa             => 'App::HomelyAlarm::Type::Severity',
        documentation   => 'Specify severity level',
        predicate       => 'has_severity',
    );
    
    around 'BUILDARGS' => sub {
        my $orig = shift;
        my $self = shift;
        my %args = @_;
        
        my $severity = App::HomelyAlarm::Utils::severity_name(delete $args{severity_level});
        if (defined $severity) {
            $args{severity} //= $severity;
        }
        return $self->$orig(%args);
    };
    
    sub severity_level {
        my ($self) = @_;
        return App::HomelyAlarm::Utils::severity_level($self->severity);
    }
}

1;
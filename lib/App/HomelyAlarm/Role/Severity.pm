package App::HomelyAlarm::Role::Severity {
    
    use Moose::Role;
    
    has 'severity_level' => (
        is              => 'rw',
        isa             => 'App::HomelyAlarm::Type::Severity',
        documentation   => 'Specify severity level',
        predicate       => 'has_severity_level',
        traits          => ['Database'],
    );
    
    around 'BUILDARGS' => sub {
        my $orig = shift;
        my $self = shift;
        my %args = @_;
        
        if (defined $args{severity_level}
            && $args{severity_level} !~ /^\d+$/) {
            $args{severity_level} = App::HomelyAlarm::Utils::severity_level($args{severity_level});
        }
        if (defined $args{severity}) {
            my $severity = delete $args{severity};
            $args{severity_level} ||= App::HomelyAlarm::Utils::severity_level($severity);
        }
        return $self->$orig(%args);
    };
    
    sub severity {
        my ($self) = @_;
        return App::HomelyAlarm::Utils::severity_name($self->severity_level);
    }
}

1;
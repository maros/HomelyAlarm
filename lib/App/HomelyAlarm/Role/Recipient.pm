package App::HomelyAlarm::Role::Recipient {
    use 5.014; 

    use Moose::Role;
    with qw(App::HomelyAlarm::Role::Severity);
    
    has 'telephone' => (
        is              => 'rw',
        isa             => 'App::HomelyAlarm::Type::Telephone',
        documentation   => 'Telephone number',
        predicate       => 'has_telephone',
        traits          => ['Filter','Database'],
    );
    
    has 'email' => (
        is              => 'rw',
        isa             => 'App::HomelyAlarm::Type::Email',
        documentation   => 'E-mail address',
        predicate       => 'has_email',
        traits          => ['Filter','Database'],
    );
    
    has 'only_vacation' => (
        is              => 'rw',
        isa             => 'Bool',
        documentation   => 'Call only during vacation',
        predicate       => 'has_only_vacation',
        traits          => ['Filter','Database'],
    );
    
    has 'only_call' => (
        is              => 'rw',
        isa             => 'Bool',
        documentation   => 'Call only - no SMS',
        predicate       => 'has_only_call',
        traits          => ['Filter','Database'],
    );
    
    sub format {
        my ($self) = @_;
        
        if ($self->has_email) {
            my $email = $self->email;
            $email = lc($email);
            $email =~ s/\s//g;
            $self->email($email);
        }
        
        if ($self->has_telephone) {
            my $telephone = $self->telephone;
            $telephone =~ s/\s//g;
            $telephone =~ s/^00/+/g;
            $telephone =~ s/[^+0-9]//g;
            $self->telephone($telephone);
        }
    }
    
    sub stringify {
        my ($self,$noflags) = @_;
        $noflags //= 0;
        
        my @contact;
        if ($self->has_email) {
            push(@contact,$self->email);
        }
        
        if($self->has_telephone) {
            push(@contact,$self->telephone);
        }
        
        my $return = join(', ',@contact);
        unless ($noflags) {
            my @flags;
            if ($self->only_call) {
                push(@flags,'call only/no sms');
            }
            if ($self->only_vacation) {
                push(@flags,'alert only during vacations');
            }
            if ($self->has_severity_level && $self->severity_level > 1) {
                push(@flags,'only '.$self->severity.' severity');
            }
            
            if (scalar @flags) {
                $return .= ' ('.join(', ',@flags).')';
            }
        }
        
        return $return;
    }
}

1;
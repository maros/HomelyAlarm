package App::HomelyAlarm::Role::Recipient {
    use 5.014; 

    use Moose::Role;
    
    has 'telephone' => (
        is              => 'rw',
        #isa             => 'App::HomelyAlarm::Type::Telephone',
        documentation   => 'Telephone number',
        predicate       => 'has_telephone',
    );
    
    has 'email' => (
        is              => 'rw',
        #isa             => 'App::HomelyAlarm::Type::Email',
        documentation   => 'E-mail address',
        predicate       => 'has_email',
    );
    
    has 'only_vacation' => (
        is              => 'rw',
        isa             => 'Bool',
        documentation   => 'Call only during vacation',
        predicate       => 'has_only_vacation',
    );
    
    has 'only_call' => (
        is              => 'rw',
        isa             => 'Bool',
        documentation   => 'Call only - no SMS',
        predicate       => 'has_only_call',
    );
    
    has 'severity' => (
        is              => 'rw',
        isa             => 'App::HomelyAlarm::Type::Severity',
        documentation   => 'Specify severity level',
        predicate       => 'has_severity',
    );
    
    sub compare_all {
        my ($self,$other) = @_;
        
        if ($self->has_only_vacation) {
            return 0
                unless $self->only_vacation == $other->only_vacation;
        }
        
        if ($self->has_only_call) {
            return 0
                unless $self->only_call == $other->only_call;
        }
        
        if ($self->has_email) {
            return 0
                unless $self->compare_email($other) == 1;
        }
        
        if ($self->has_telephone) {
            return 0
                unless $self->compare_telephone($other) == 1;
        }
        
        return 1;
    }
    
    
    sub compare_email {
        my ($self,$other) = @_;
        
        return -1
            unless $self->has_email
            && $other->has_email;
        
        return 1
            if $self->email eq $other->email;
        
        return 0;
    }
    
    sub compare_telephone {
        my ($self,$other) = @_;
        
        return -1
            unless $self->has_telephone
            && $other->has_telephone;
        
        return 1
            if $self->telephone eq $other->telephone;
        
        return 0;
    }
    
    sub compare_any {
        my ($self,$other) = @_;
        
        return 1
            if $self->compare_email($other) == 1;
        return 1
            if $self->compare_telephone($other) == 1;
        
        return 0;
    }
    
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
        my ($self) = @_;
        
        my (@contact,@flags);
        if ($self->has_email) {
            push(@contact,$self->email);
        }
        
        if($self->has_telephone) {
            push(@contact,$self->telephone);
        }
        
        if ($self->only_call) {
            push(@flags,'call only/no sms');
        }
        if ($self->only_vacation) {
            push(@flags,'alert only during vacations');
        }
        if ($self->has_severity) {
            push(@flags,'only '.$self->severity.' severity');
        }
        
        my $return = join(', ',@contact);
        if (scalar @flags) {
            $return .= ' ('.join(', ',@flags).')';
        }
        return $return;
    }
}

1;
package App::HomelyAlarm::Role::Recipient {
    use 5.014; 

    use Moose::Role;
    
    has 'telephone' => (
        is              => 'rw',
        isa             => 'App::HomelyAlarm::Type::Telephone',
        documentation   => 'Telephone number',
        predicate       => 'has_telephone',
    );
    
    has 'email' => (
        is              => 'rw',
        isa             => 'App::HomelyAlarm::Type::Email',
        documentation   => 'E-mail address',
        predicate       => 'has_email',
    );
    
    has 'only_vacation' => (
        is              => 'rw',
        isa             => 'Bool',
        documentation   => 'Call only during vacation',
        predicate       => 'has_only_vacation',
    );
}

1;
package App::HomelyAlarm::Call {
    use 5.014; 

    use namespace::autoclean;
    use Moose;
    
    our %INSTANCES;
    
    has 'sid' => (
        is      => 'rw',
        required=> 1,
    );
    
    has 'message' => (
        is      => 'rw',
        required=> 1,
    );
    
    has 'timer' => (
        is      => 'ro',
        default => sub {
            my ($self) = @_;
            AnyEvent->timer( 
                after   => 60, 
                cb      => sub { $self->check_call() }
            );
        }
    );
    
    has 'time' => (
        is      => 'ro',
        default => sub {
            return time();
        }
    );
    
    has 'callee' => (
        is      => 'ro',
        required=> 1,
    );
    
    sub BUILD {
        my ($self) = @_;
        $INSTANCES{$self->sid} = $self;
    }
    
    sub DEMOLISH {
        my ($self) = @_;
        delete $INSTANCES{$self->sid};
    }
    
    sub check_call {
        my ($self) = @_;
        my $app = App::HomelyAlarm->app_instance;
        $app->run_request(
            'GET',
            'Calls/'.$self->sid,
            From            => $app->caller_number,
            sub {
                my ($data,$headers) = @_;
#'duration' => '16',
#'parent_call_sid' => undef,
#'api_version' => '2010-04-01',
#'phone_number_sid' => '',
#'answered_by' => undef,
#'account_sid' => 'AC6c08808911263d2e3626d2772a332d42',
#'from' => '+15179925427',
#'forwarded_from' => undef,
#'from_formatted' => '(517) 992-5427',
#'price' => '-0.15000',
#'uri' => '/2010-04-01/Accounts/AC6c08808911263d2e3626d2772a332d42/Calls/CA70a6c67b1a4a133a88d1fee95e9a6626.json',
#'date_updated' => 'Sat, 12 Jul 2014 21:57:36 +0000',
#'price_unit' => 'USD',
#'status' => 'completed',
#'sid' => 'CA70a6c67b1a4a133a88d1fee95e9a6626',
#'end_time' => 'Sat, 12 Jul 2014 21:57:36 +0000',
#'subresource_uris' => {
#                        'notifications' => '/2010-04-01/Accounts/AC6c08808911263d2e3626d2772a332d42/Calls/CA70a6c67b1a4a133a88d1fee95e9a6626/Notifications.json',
#                        'recordings' => '/2010-04-01/Accounts/AC6c08808911263d2e3626d2772a332d42/Calls/CA70a6c67b1a4a133a88d1fee95e9a6626/Recordings.json'
#                      },
#'start_time' => 'Sat, 12 Jul 2014 21:57:20 +0000',
#'date_created' => 'Sat, 12 Jul 2014 21:57:11 +0000',
#'group_sid' => undef,
#'to_formatted' => '+4369981286682',
#'caller_name' => '',
#'to' => '+4369981286682',
#'annotation' => undef,
#'direction' => 'outbound-api'
                delete $INSTANCES{$self->sid}
            },
        );
    }
    
    sub all_calls {
        my ($class) = @_;
        return keys %INSTANCES;
    }
    
    sub get_call {
        my ($class,$sid) = @_;
        return $INSTANCES{$sid};
    }
    
    sub remove_call {
        my ($class,$sid) = @_;
        return delete $INSTANCES{$sid};
    }
    
    __PACKAGE__->meta->make_immutable;
};

1;
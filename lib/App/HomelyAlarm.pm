package App::HomelyAlarm {
    use 5.014; 
    
    our $AUTHORITY = 'cpan:MAROS';
    our $VERSION = '1.00';
    
    use MooseX::App::Simple qw(Color);
    
    use AnyEvent;
    use Twiggy::Server;
    use Plack::Request;
    use WWW::Twilio::API;
    
    option 'port' => (
        is              => 'rw',
        isa             => 'Int',
        documentation   => 'Listening port',
        default         => 1222,
    );
    
    option 'host' => (
        is              => 'rw',
        isa             => 'Str',
        documentation   => 'Bind host',
        default         => '',
    );
    
    option 'alarmtimer' => (
        is              => 'rw',
        isa             => 'Int',
        documentation   => 'Default alarm timer',
        default         => 60,
    );
    
    option 'twilio_sid' => (
        is              => 'rw',
        isa             => 'Str',
        required        => 1,
    );
    
    option 'twilio_authtoken' => (
        is              => 'rw',
        isa             => 'Str',
        required        => 1,
    );
    
    has 'timer' => (
        is              => 'rw',
        clearer         => 'clear_timer',
        predicate       => 'has_timer',
    );
    
    has 'twilio' => (
        is              => 'rw',
        lazy_build      => 1,
    );
    
    sub run {
        my ($self) = @_;
 
        # Initalize condvar
        my $cv = AnyEvent->condvar;
        
        # Signal handler
        my $term_signal = AnyEvent->signal(
            signal  => "TERM", 
            cb      => sub { 
                _log('Recieved INT signal');
                $cv->send;
            }
        );
        my $int_signal = AnyEvent->signal(
            signal  => "INT", 
            cb      => sub { 
                _log('Recieved INT signal');
                $cv->send;
            }
        );
        
        _log('Startup server');
        
        # Start server
        my $server = Twiggy::Server->new(
            host => $self->host,
            port => $self->port,
        );
        
        # Register service
        $server->register_service(sub {
            my ($env) = @_;
            my $req = Plack::Request->new($env);
            
            unless ($req->method eq 'POST') {
                return _reply_error(405)
            }
            unless ($req->header('Authorization') 
                && authenticate($req->header('Authorization'))) {
                return _reply_error(401)
            }
            
            if ($req->path_info eq 'intrusion') {
                $req->input->read( my $buffer, $req->header("Content-Length"), 0 );
                $self->timer(AnyEvent->timer( after => $self->alarmtimer, cb => sub { $self->run_alarm($buffer) } ))
                    unless $self->has_timer;
                _reply_ok();
            } elsif ($req->path_info eq 'alarm') {
                $req->input->read( my $buffer, $req->header("Content-Length"), 0 );
                $self->run_alarm($buffer);
                _reply_ok();
            } elsif ($req->path_info eq 'reset') {
                $self->clear_timer();
                _reply_ok();
            } else {
                 return _reply_error(404)
            }
        });
 
        $cv->recv;
    }
    
    sub run_alarm {
        my ($self,$message) = @_;
        $self->clear_timer();
        _log("Running alarm");
        
        # TODO notify email/phone
    } 
    
    sub _log {
        my ($message) = @_;
        say "[LOG] $message";
    }
    
    sub _reply_ok {
        return [
            200,
            [ 'Content-Type' => 'text/plain' ],
            [ "OK" ],
        ];
    }
    
    sub _reply_error {
        my ($code) = @_;
        
        _log("Invalid request: $code");
        return [
            $code,
            [ 'Content-Type' => 'text/plain' ],
            [ "Error:".$code ],
        ];
    }
    
    sub authenticate {
        # TODO authenticate
    }
}

1;
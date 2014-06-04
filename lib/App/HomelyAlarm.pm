package App::HomelyAlarm {
    use 5.014; 
    
    our $AUTHORITY = 'cpan:MAROS';
    our $VERSION = '1.00';
    
    use MooseX::App::Simple qw(Color ConfigHome);
    
    #use Coro;
    use AnyEvent;
    use Twiggy::Server;
    use Plack::Request;
    use WWW::Twilio::API;
    use Try::Tiny;
    use Digest::HMAC_SHA1 qw(hmac_sha1);
    
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
    
    option 'secret' => (
        is              => 'rw',
        isa             => 'Str',
        required        => 1,
    );
    
    has 'timer' => (
        is              => 'rw',
        clearer         => 'clear_timer',
        predicate       => 'has_timer',
    );
    
    has 'message' => (
        is              => 'rw',
        clearer         => 'clear_message',
        predicate       => 'has_message',
    );
    
    has 'twilio' => (
        is              => 'rw',
        lazy_build      => 1,
    );
    
    sub _build_twilio {
        my ($self) = @_;
        return WWW::Twilio::API->new(
            AccountSid => $self->twilio_sid,
            AuthToken  => $self->twilio_authtoken,
        );
    }
    
    
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
            my ($env)   = @_;
            my $req     = Plack::Request->new($env);
            my @paths   = grep { $_ } split('/',$req->path_info);
            my $method  = join('_','dispatch',$req->method,@paths);
            my $authen  = join('_','authenticate',$paths[0]);
            
            my $coderef = $self->can($method);
            if ($coderef) {
                if ($self->can($authen) && ! $self->$authen($req)) {
                    return _reply_error(401);
                }
                _log("Handling $method");
                
                my $response = try {
                    return $self->$coderef($req);
                } catch {
                    _log("Error processing $method: $_");
                    return _reply_error(500)
                }
            } else {
                return _reply_error(404)
            }
        });
 
        $cv->recv;
        
        _log('End loop');
    }
    
    sub dispatch_POST_alarm_intrusion {
        my ($self,$req) = @_;
        
        return _reply_ok(401)
            unless $self->authenticate_alarm();
        
        unless ($self->has_timer) {
            $req->input->read( my $buffer, $req->header("Content-Length"), 0 );
            _log("Set alarm intrusion timer: $buffer");
            $self->timer(AnyEvent->timer( 
                after   => $self->alarmtimer, 
                cb      => sub { $self->run_alarm($buffer) }
            ));
        }
            
        _reply_ok();
    }
    
    sub dispatch_POST_alarm_reset {
        my ($self,$req) = @_;
        
        return _reply_ok(401)
            unless $self->authenticate_alarm($req);
        
        _log("Reset alarm intrusion timer");
        
        $self->clear_timer();
        return _reply_ok();
    }
    
    sub dispatch_POST_alarm_run {
        my ($self,$req) = @_;
        
        return _reply_ok(401)
            unless $self->authenticate_alarm($req);
        
        $req->input->read( my $buffer, $req->header("Content-Length"), 0 );
        _log("Run immediate alarm: $buffer");
        $self->run_alarm($buffer);
        
        _reply_ok();     
    }
    
    sub dispatch_POST_call_fallback {
        my ($self,$req) = @_;
        
        return _reply_ok(401)
            unless $self->authenticate_call($req);
        
        my $message = $self->message || 'Unknown reason';
        
        _log("Call failed");
        
    }
    
    sub dispatch_GET_call_twiml {
        my ($self,$req) = @_;
        
        return _reply_ok(401)
            unless $self->authenticate_call($req);
        
        my $message = $self->message || 'Unknown reason';
        return [
            200,
            [ 'Content-Type' => 'text/xml' ],
            [ <<TWIML
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="woman" language="en-US">Alarm triggered!</Say>
    <Say voice="woman" language="en-US">$message</Say>
    <Hangup/>
</Response>
TWIML
            ],
        ];
    }

    sub run_alarm {
        my ($self,$message) = @_;
        $self->clear_timer();
        $self->clear_message();
        $self->message($message);
        
        _log("Running alarm");
        
        $self->twilio->POST( 
            'Calls',
            From            => $self->caller_number,
            To              => $self->callee_number,
            Url             => $self->self_url('/call/twiml'),
            Method          => 'GET',
            FallbackUrl     => $self->self_url('/call/fallback'),
            FallbackMethod  => 'POST',
            Record          => 'false',
            Timeout         => 60,
        );
    } 
    
    sub authenticate_alarm {
        my ($self,$req) = @_;
        my $auth = $req->header('Authorization');
        
        unless (defined $auth
            && $auth eq $self->secret) {
            _log('Could not authenticate alarm');
            return 0;
        }
        return 1;
    }
    
    sub authenticate_call {
        my ($self,$req) = @_;
        my $sid         = $req->param('AccountSid');
        my $signature   = $req->param('X-Twilio-Signature');
        my $digest      = hmac_sha1($req->uri, $self->twilio_authtoken);
        
        unless (defined $sid
            && $sid eq $self->twilio_sid
            && defined $signature
            && $signature eq $digest) {
            _log('Could not authenticate call');
            return 0;
        }
        
        return 1;
    }
    
    sub self_url {
        my ($self,$req,@path) = @_;
        return $req->scheme.'://'.join('/',$req->env->{HTTP_HOST},@path);
    }
    
    sub _log {
        my ($message) = @_;
        say "[LOG] $message";
    }
    
    sub _reply_ok {
        my ($message) = @_;
        $message ||= 'OK';
        return [
            200,
            [ 'Content-Type' => 'text/plain' ],
            [ $message ],
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
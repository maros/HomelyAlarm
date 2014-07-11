package App::HomelyAlarm {
    use 5.014; 
    
    our $AUTHORITY = 'cpan:MAROS';
    our $VERSION = '1.00';
    
    use MooseX::App::Simple qw(Color Config);
    
    use AnyEvent;
    use AnyEvent::HTTP;
    use Twiggy::Server;
    use Plack::Request;
    use Try::Tiny;
    use Digest::HMAC_SHA1 qw(hmac_sha1_hex hmac_sha1);
    use JSON::XS;
    use MIME::Base64 qw(encode_base64);
    use URI::Escape qw(uri_escape);
    
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
    
    option 'caller_number' => (
        is              => 'rw',
        isa             => 'Str',
        required        => 1,
    );
    
    option 'callee_number' => (
        is              => 'rw',
        isa             => 'ArrayRef[Str]',
        required        => 1,
    );
    
    has 'timer' => (
        is              => 'rw',
        predicate       => 'has_timer',
        clearer         => 'clear_timer',
    );

    has 'self_url' => (
        is              => 'rw',
        predicate       => 'has_self_url',
    );

    has 'calls' => (
        is              => 'ro',
        default         => sub { {} },
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
        $server->register_service($self->app);
         
        $cv->recv;
        
        _log('End loop');
    }
    
    sub app {
        my ($self) = @_;
        
        return sub {
            my ($env)   = @_;

            _log("HomelyAlarm needs a server that supports psgi.streaming and psgi.nonblocking")
                unless $env->{'psgi.streaming'} && $env->{'psgi.nonblocking'};
            
            my $req     = Plack::Request->new($env);
            my @paths   = grep { $_ } split('/',$req->path_info);
            
            return _reply_error(404)
                unless scalar @paths;
            
            my $method  = join('_','dispatch',$req->method,@paths);
            my $authen  = join('_','authenticate',$paths[0]);
            
            unless ($self->has_self_url) {
                my $url = $req->scheme.'://'.$req->env->{HTTP_HOST};
                $self->self_url($url);
            }
            
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
        };
    }
    
    sub dispatch_POST_alarm_intrusion {
        my ($self,$req) = @_;
        
        unless ($self->has_timer) {
            $self->timer(AnyEvent->timer( 
                after   => $req->param('timer') || 60, 
                cb      => sub { $self->run_notify($req->param('message')) }
            ));
        }
            
        _reply_ok();
    }
    
    sub dispatch_POST_alarm_reset {
        my ($self,$req) = @_;
        
        _log("Reset alarm intrusion timer");
        
        $self->clear_timer();
        return _reply_ok();
    }
    
    sub dispatch_POST_alarm_run {
        my ($self,$req) = @_;
        
        my $message = $req->param('message');
        _log("Run immediate alarm: $message");
        $self->run_notify($message);
        
        _reply_ok();
    }
    
    sub dispatch_POST_alarm_alert {
        my ($self,$req) = @_;
        
        my $message = $req->param('message');
        _log("Run alert: $message");
        $self->run_notify($message);
        
        _reply_ok();
    }
    
    sub dispatch_POST_call_fallback {
        my ($self,$req) = @_;
        # TODO terminate call
        _log("Call failed");
        
    }
    
    sub dispatch_GET_call_twiml {
        my ($self,$req) = @_;
        
	# TODO get call message
	my $message;
        return [
            200,
            [ 'Content-Type' => 'text/xml' ],
            [ <<TWIML
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="woman" language="en-US">$message</Say>
    <Hangup/>
</Response>
TWIML
            ],
        ];
    }
    
    sub run_request {
	my $self = shift;
	my $method = shift;
	my $action = shift;
	my $callback = pop;
	my %args = @_;
        
        my $url = 'https://api.twilio.com/2010-04-01/Accounts/'.$self->twilio_sid.'/'.$action.'.json';
        
        my %params = (
            timeout => 120,
            headers => {
                'Authorization' => 'Basic '.MIME::Base64::encode($self->twilio_sid.":".$self->twilio_authtoken, ''),
            },
        );
        
        my $content = '';
        my @args;
        
        for my $key ( keys %args ) {
            $args{$key} = ( defined $args{$key} ? $args{$key} : '' );
            push @args, uri_escape($key) . '=' . uri_escape($args{$key});
        }
        $content = join('&', @args) || '';
        
        if( $method eq 'GET' ) {
            $url .= '?' . $content;
        } elsif ($method eq 'POST') {
            $params{headers}{'Content-Type'} = 'application/x-www-form-urlencoded';
            $params{body} = $content;
        }
        
        http_request( 
            $method,
            $url, 
            %params, 
            sub {
                my ($data,$headers) = @_;
                my $api_response = JSON::XS::decode_json($data);
                if ($headers->{Status} =~ /^2/) {
                    $callback->($api_response,$headers);
                } else {
                    _log("Error placing call: ".$data)
                }
            }
        );
    }

    sub run_notify {
        my ($self,$message) = @_;
        $self->clear_timer();
        
	my $timestamp = time();
        _log("Running alarm");
        foreach my $callee (@{$self->callee_number}) {
            $self->run_request(
                'POST',
                'Calls',
                From            => $self->caller_number,
                To              => $callee,
                Url             => $self->self_url.'/call/twiml',
                Method          => 'GET',
                FallbackUrl     => $self->self_url.'/call/fallback',
                FallbackMethod  => 'POST',
                Record          => 'false',
                Timeout         => 60,
                sub {
                    my ($data,$headers) = @_;
                    $self->register_call(
                        $data->{sid},
                        to          => $data->{to_formated},
                        message     => $message,
                        timestamp   => $timestamp,
                    );
                },
            );
        }
    }
    
    sub authenticate_alarm {
        my ($self,$req) = @_;
        
        my $signature = $req->header('X-HomelyAlarm-Signature');
        
        if (defined $signature) {
            my $digest = hmac_sha1_hex($req->uri, $self->secret);
            return 1
                if ($signature eq $digest);
        }
        
        _log('Could not authenticate call');
        return 0;
    }
    
    sub authenticate_call {
        my ($self,$req) = @_;
        my $sid         = $req->param('AccountSid');
        my $signature   = $req->header('X-Twilio-Signature');
        my $key         = $req->uri;
        if ($req->method eq 'POST') {
            my $body = $req->body_parameters;
            $key .= join('',map { $_.$body->{$_} } sort keys %{$body});
        }
        my $digest      = encode_base64(hmac_sha1($key, $self->twilio_authtoken));
        chomp($digest);
        
        unless (defined $sid
            && $sid eq $self->twilio_sid
            && defined $signature
            && $signature eq $digest) {
            _log('Could not authenticate call');
            return 0;
        }
        
        return 1;
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

    sub register_call {
        my ($self,$sid,%call) = @_;
        $self->calls->{$sid} = \%call;
    }
    
    sub get_call {
        my ($self,$sid) = @_;
        # TODO get call
    }
}

1;

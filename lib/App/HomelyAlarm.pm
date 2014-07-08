package App::HomelyAlarm {
    use 5.014; 
    
    our $AUTHORITY = 'cpan:MAROS';
    our $VERSION = '1.00';
    
    use MooseX::App::Simple qw(Color Config);
    
    #use Coro;
    use AnyEvent;
    use Twiggy::Server;
    use Plack::Request;
    use WWW::Twilio::API;
    use Try::Tiny;
    use Digest::HMAC_SHA1 qw(hmac_sha1_hex hmac_sha1);
    use JSON::XS;
    use MIME::Base64 qw(encode_base64);
    
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
    
    has 'self_url' => (
        is              => 'rw',
        predicate       => 'has_self_url',
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
        $server->register_service($self->app);
         
        $cv->recv;
        
        _log('End loop');
    }
    
    sub app {
        my ($self) = @_;
        
        return sub {
            my ($env)   = @_;
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
        
        #$self->message($req->param('message'));
        unless ($self->has_timer) {
            $self->timer(AnyEvent->timer( 
                after   => $req->param('timer') || 60, 
                cb      => sub { $self->run_alarm($req->param('message')) }
            ));
        }
            
        _reply_ok();
    }
    
    sub dispatch_POST_alarm_reset {
        my ($self,$req) = @_;
        
        _log("Reset alarm intrusion timer");
        
        $self->clear_message();
        $self->clear_timer();
        return _reply_ok();
    }
    
    sub dispatch_POST_alarm_run {
        my ($self,$req) = @_;
        
        my $message = $req->param('message');
        _log("Run immediate alarm: $message");
        $self->run_alarm($message);
        
        _reply_ok();
    }
    
    sub dispatch_POST_alarm_message {
        my ($self,$req) = @_;
        
        my $message = $req->param('message');
        _log("Run message: $message");
        $self->run_alarm($message);
        
        _reply_ok();
    }
    
    sub dispatch_POST_call_fallback {
        my ($self,$req) = @_;
        
        my $message = $self->message || 'Unknown reason';
        
        _log("Call failed");
        
    }
    
    sub dispatch_GET_call_twiml {
        my ($self,$req) = @_;
        
        my $message = $self->message || 'Unknown reason';
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

    sub run_alarm {
        my ($self,$message) = @_;
        $self->clear_timer();
        $self->clear_message();
        $self->message($message);
        
        _log("Running alarm");
        my $response = $self->twilio->POST( 
            'Calls.json',
            From            => $self->caller_number,
            To              => $self->callee_number,
            Url             => $self->self_url.'/call/twiml',
            Method          => 'GET',
            FallbackUrl     => $self->self_url.'/call/fallback',
            FallbackMethod  => 'POST',
            Record          => 'false',
            Timeout         => 60,
        );
        
        if ($response->{code} == 201) {
            my $api_response = JSON::XS::decode_json($response->{content});
            use Data::Dumper;
            warn Data::Dumper::Dumper($api_response);
#{
#      'caller_name' => undef,
#      'to_formatted' => '+43xxxxx',
#      'start_time' => undef,
#      'phone_number_sid' => undef,
#      'api_version' => '2010-04-01',
#      'status' => 'queued',
#      'from' => '+151xxxxx',
#      'to' => '+43xxxxx',
#      'uri' => '/2010-04-01/Accounts/AC6cxxxx/Calls/CAexxxx.json',
#      'group_sid' => undef,
#      'price' => undef,
#      'annotation' => undef,
#      'price_unit' => 'USD',
#      'date_created' => undef,
#      'forwarded_from' => undef,
#      'parent_call_sid' => undef,
#      'direction' => 'outbound-api',
#      'date_updated' => undef,
#      'subresource_uris' => {
#          'notifications' => '/2010-04-01/Accounts/AC6cxxxx/Calls/CAexxxx/Notifications.json',
#          'recordings' => '/2010-04-01/Accounts/AC6cxxxx/Calls/CAexxxx/Recordings.json'
#      },
#      'from_formatted' => '(517) 9xx-5xxx',
#      'end_time' => undef,
#      'duration' => undef,
#      'answered_by' => undef,
#      'account_sid' => 'AC6cxxxx',
#      'sid' => 'CAexxxx'
#};
        } else {
            _log("Error placing call: ".$response->{content})
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
}

1;
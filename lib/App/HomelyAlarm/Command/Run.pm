package App::HomelyAlarm::Command::Run {
    use 5.014;
    
    use MooseX::App::Command;
    extends qw(App::HomelyAlarm);
    
    use AnyEvent::HTTP;
    use Twiggy::Server;
    use AnyEvent;
    use Plack::Request;
    use Try::Tiny;
    use JSON::XS;
    use Digest::HMAC_SHA1 qw(hmac_sha1_hex hmac_sha1);
    use MIME::Base64 qw(encode_base64);
    use URI::Escape qw(uri_escape);
    use Email::Stuffer;
    
    use  App::HomelyAlarm::TwilioTransaction;
    
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
        documentation   => 'Twilio Account SID',
        required        => 1,
    );
    
    option 'twilio_authtoken' => (
        is              => 'rw',
        isa             => 'Str',
        documentation   => 'Twilio Authentication Token',
        required        => 1,
    );
    
    option 'secret' => (
        is              => 'rw',
        isa             => 'Str',
        documentation   => 'Alarm server secret',
        required        => 1,
    );
    
    option 'caller_number' => (
        is              => 'rw',
        isa             => 'Str',
        documentation   => 'Caller telephone number',
        required        => 1,
    );
    
    option 'sender_email' => (
        is              => 'rw',
        isa             => 'Str',
        documentation   => 'Sender e-mail address',
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
    
    our $INSTANCE;
    
    sub run {
        my ($self) = @_;
 
        # Initalize condvar
        my $cv = AnyEvent->condvar;
        
        $INSTANCE = $self;
        
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
        
        $INSTANCE = undef;
        
        _log('End loop');
    }
    
    sub app_instance {
        return $INSTANCE;
    }
    
    sub app {
        my ($self) = @_;
        
        return sub {
            my ($env)   = @_;

            _log("HomelyAlarm needs a server that supports psgi.streaming and psgi.nonblocking")
                unless $env->{'psgi.streaming'} && $env->{'psgi.nonblocking'};
            
            my $req     = Plack::Request->new($env);
            my @paths   = grep { $_ } split('/',$req->path_info);
            
            return _reply_error(404,"Not Found",$req)
                if scalar @paths != 2
                || $req->path_info =~ /_/;
            
            my $method  = join('_','dispatch',$req->method,@paths);
            my $authen  = join('_','authenticate',$paths[0]);
            
            unless ($self->has_self_url) {
                my $url = $req->scheme.'://'.$req->env->{HTTP_HOST};
                $self->self_url($url);
            }
            
            my $coderef = $self->can($method);
            if ($coderef) {
                if ($self->can($authen) && ! $self->$authen($req)) {
                    return _reply_error(401,"Not authorized",$req);
                }
                _log("Handling $method");
                
                my $response = try {
                    return $self->$coderef($req);
                } catch {
                    _log("Error processing $method: $_");
                    return _reply_error(500,"Internal Server Error",$req)
                }
            } else {
                return _reply_error(404,"Not Found",$req)
            }
        };
    }
    
    sub dispatch_POST_alarm_intrusion {
        my ($self,$req) = @_;
        
        unless ($self->has_timer) {
            my $message = $req->param('message');
            my $severity = $req->param('severity') || "high";
            
            $self->timer(AnyEvent->timer( 
                after   => $req->param('timer') || 60, 
                cb      => sub { 
                    $self->run_notify($message,$severity) 
                }
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
        my $severity = $req->param('severity') || "high";
        _log("Run immediate alarm: $message");
        $self->run_notify($message,$severity);
        
        _reply_ok();
    }
    
    *dispatch_POST_alarm_alert = \&dispatch_POST_alarm_run;
    
    sub dispatch_POST_twilio_status {
        my ($self,$req) = @_;
        
        my $sid;
        
        if ($sid = $req->param('CallSid')) {
            my $transaction = App::HomelyAlarm::TwilioTransaction->remove_sid($sid);
            return _reply_error(404,"Call not found",$req)
                unless $transaction;
            
            _log("Transaction status ".$transaction->callee.": ".$req->param('CallStatus'));
            if ($req->param('CallStatus') ne 'completed') {
                # send fallback SMS
                $self->run_sms($transaction->callee,$transaction->message,$transaction->severity);
            }
        } elsif ($sid = $req->param('SmsSid')) {
            my $transaction = App::HomelyAlarm::TwilioTransaction->remove_sid($sid);
            return _reply_error(404,"SMS not found",$req)
                unless $transaction;
            
            _log("SMS status ".$transaction->callee.": ".$req->param('SmsStatus'));
        } else {
            _reply_error(404,"Missing parameters",$req)
        }
    }
    
    sub dispatch_GET_twilio_twiml {
        my ($self,$req) = @_;
        
        my $call = App::HomelyAlarm::TwilioSid->get_call($req->param('CallSid'));
        return _reply_error(404,"Call not found",$req)
            unless $call;
        
        my $message = $call->message;
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
        
        _log("Twilio request $method $url");
        
        my $guard;
        $guard = http_request( 
            $method,
            $url, 
            %params, 
            sub {
                my ($data,$headers) = @_;
                $guard = undef;
                my $api_response = JSON::XS::decode_json($data);
                if ($headers->{Status} =~ /^2/) {
                    $callback->($api_response,$headers);
                } else {
                    _log("Error placing call: ".$data)
                }

            }
        );
    }
    
    sub run_email {
        my ($self,$recipient,$message,$severity) = @_;
        
        Email::Stuffer
            ->from($self->sender_email)
            ->to($recipient->email)
            ->subject('HomelyAlarmAlert:'.$message)
            ->text_body(qq[
                Message:  $message
                Severity: $severity
                --
                Sent by HomelyAlarm
            ])
            ->send();
    }
    
    sub run_sms {
        my ($self,$recipient,$message,$severity) = @_;
        
        $self->run_request(
            'POST',
            'Messages',
            From            => $self->caller_number,
            To              => $recipient->telephone,
            Body            => $message,
            StatusCallback  => $self->self_url.'/twilio/status',
            StatusMethod    => 'POST',
            sub {
                my ($data,$headers) = @_;
                App::HomelyAlarm::TwilioTransaction->new(
                    message     => $message, 
                    callee      => $data->{to_formatted},
                    sid         => $data->{sid},
                    severity    => $severity,
                );
            },
        )
    }
    
    sub run_call {
        my ($self,$recipient,$message,$severity) = @_;
        
        $self->run_request(
            'POST',
            'Calls',
            From            => $self->caller_number,
            To              => $recipient->telephone,
            Url             => $self->self_url.'/twilio/twiml',
            Method          => 'GET',
            StatusCallback  => $self->self_url.'/twilio/status',
            StatusMethod    => 'POST',
            Record          => 'false',
            Timeout         => 60,
            sub {
                my ($data,$headers) = @_;
                App::HomelyAlarm::TwilioTransaction->new(
                    message => $message, 
                    callee  => $data->{to_formatted},
                    sid     => $data->{sid},
                    severity=> $severity,
                );
            },
        );
    }

    sub run_notify {
        my ($self,$message,$severity) = @_;
        $self->clear_timer();
        _log("Running alarm");
        
        foreach my $recipient ($self->recipients_list) {
            given ($severity) {
                when ('low') {
                    $self->run_email($message,$severity,$recipient);
                }
                when ('medium') {
                    $self->run_sms($message,$severity,$recipient);
                }
                when ('high') {
                    $self->run_call($message,$severity,$recipient);
                }
            }
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
        
        _log('Could not authenticate alarm');
        return 0;
    }
    
    sub authenticate_twilio {
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
        say STDERR "[LOG] $message";
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
        my ($code,$message,$req) = @_;
        
        _log("Invalid request to ".$req->uri.": $message ($code)");
        return [
            $code,
            [ 'Content-Type' => 'text/plain' ],
            [ "Error:$code\n$message" ],
        ];
    }
    
    __PACKAGE__->meta->make_immutable;
    
=head1 NAME

App::HomelyAlarm::Command::Run - Run the HomelyAlarm Server

=cut
}

1;
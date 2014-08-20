# -*- perl -*-

# t/basic.t - test basic usage

use Test::Most tests => 24+1;
use Test::NoWarnings;

use strict;
use warnings;

use Plack::Test;
use HTTP::Request::Common;
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);
use MIME::Base64 qw(encode_base64);

use_ok( 'App::HomelyAlarm::Command::Run' ); 

my $recipients_database = 't/testdb.db';
unlink($recipients_database);

{
    package App::HomelyAlarm::Test;
    use Moose;
    extends qw(App::HomelyAlarm::Command::Run);
    
    has 'last_request' => (
        is      => 'rw',
        clearer => 'reset_last_request',
    );
    
    sub run_twilio {
        my $self = shift;
        my $method = shift;
        my $action = shift;
        my $callback = pop;
        $callback->({ sid => 'FakeSid' },{});
        $self->last_request({
            method  => $method,
            action  => $action,
            @_
        });
    }
}

my $ha = App::HomelyAlarm::Test->new(
    twilio_sid          => 'SID',
    twilio_authtoken    => 'AUTHTOKEN',
    secret              => 'SECRET',
    caller_number       => '123456789',
    sender_email        => 'homely_alarm@cpan.org',
    database            => $recipients_database,
);

my $recipient = App::HomelyAlarm::Recipient->new(
    email       => 'test@k-1.com',
    telephone   => '+431234567890',
);

$recipient->store($ha->storage);

my $test = Plack::Test->create($ha->app);

# Test 404
{
    my $res = $test->request(GET "/nosuchurl");
    is($res->code,404,'Not found');
}

# Test 401
{
    my $res = $test->request(POST "/alarm/reset");
    is($res->code,401,'Not authenticated');
}

# Test basic
{
    my $res = alarm_request('reset');
    is($res->code,200,'Status ok');
    is($res->content,'OK','Response ok');
}

# Test alarm
{
    my $res = alarm_request('intrusion','Test alarm was detected');
    is($res->code,200,'Status ok');
    is($res->content,'OK','Response ok');
    ok($ha->has_timer,'Timer is set');
    #ok($ha->has_message,'Message is set');
    #is($ha->message,'Test alarm was detected','Message is set');
    #isa_ok($ha->timer,'EV::Timer');
    $ha->clear_timer();
}

# Test alarm reset
{
    ok(!$ha->has_timer,"Has no timer");
    my $res1 = alarm_request('intrusion','Test alarm was detected');
    is($res1->code,200,'Status ok');
    ok($ha->has_timer,"Has timer");
    my $res2 = alarm_request('reset','Reset alarm');
    is($res2->code,200,'Status ok');
    ok(!$ha->has_timer,"Has no more timer");
}

# Test immediate alarm
{
    my $res = alarm_request('run','Test alarm run');
    is($res->code,200,'Status ok');
    is($ha->last_request->{From},$ha->caller_number,'Has correct caller number');
    is($ha->last_request->{To},$recipient->telephone,'Has correct callee number');
    $ha->reset_last_request;
}

## Test call
#{
#    my $res = call_request('twiml','GET',{});
#    is($res->code,200,'Status ok');
#    like($res->content,qr/Test alarm run/,'Response ok');
#}

# Test delayed alarm
{
    my $cv = AnyEvent->condvar;
    my $res = alarm_request('intrusion','Test alarm intrusion',1);
    is($res->code,200,'Status ok');
    is($ha->last_request,undef,"No lastcall yet");
    ok($ha->has_timer,"Has timer");
    my $timer = AnyEvent->timer (
        after => 3, 
        cb => sub { 
            fail("Did not get twilio call"); 
            $cv->send; 
        }
    );
    my $wait = AnyEvent->idle (cb => sub { 
        if ($ha->last_request) {
            pass("Got twilio callback");
            $cv->send;
        }
    });
    $cv->recv;
}

# Test message log
{
     my @message_log = $recipient->message_log($ha->storage);
     is(scalar @message_log,2,'Has two messages');
     is($message_log[0]->message,'Test alarm run','First message ok');
     is($message_log[0]->severity,'high','First severity ok');
     is($message_log[1]->message,'Test alarm intrusion','Second message ok');
}

#unlink $recipients_database;

sub alarm_request {
    my ($path,$message,$timer) = @_;
    $message ||= 'empty';
    my $url = '/alarm/'.$path.'?time='.time().'&message='.$message;
    $url .= '&timer='.$timer
        if defined $timer;
    my $r = HTTP::Request->new('POST',$url);
    my $key = 'http://localhost'.$r->uri;
    my $digest = hmac_sha1_hex($key,$ha->secret);
    $r->header('X-HomelyAlarm-Signature' => $digest);
    return $test->request($r);
}

#sub call_request {
#    my ($path,$method,$params) = @_;
#    $params->{AccountSid} = $ha->twilio_sid;
#    my $url = '/call/'.$path.'?'.join('&',map { $_.'='.$params->{$_} } sort keys %{$params});
#    my $r = HTTP::Request->new($method,$url);
#    my $key = 'http://localhost'.$r->uri;
#    my $digest = encode_base64(hmac_sha1_hex($key,$ha->twilio_authtoken));
#    $r->header('X-Twilio-Signature' => $digest);
#    return $test->request($r);
#}

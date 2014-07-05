# -*- perl -*-

# t/00_load.t - check module loading and create testing directory

use Test::Most tests => 36;

use Plack::Test;
use HTTP::Request::Common;
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);

use_ok( 'App::HomelyAlarm' ); 

{
    package TwilioMock;
    our $LASTCALL;
    sub POST {
        warn "CALL POST";
        $LASTCALL = { @_ };
    };
    sub get_lastcall {
        return $LASTCALL;
    }
    sub reset_lastcall {
        $LASTCALL = undef;
    }
}

my $ha = App::HomelyAlarm->new(
    twilio_sid          => 'SID',
    twilio_authtoken    => 'AUTHTOKEN',
    secret              => 'SECRET',
    caller_number       => '123456789',
);

my $twilio_original = $ha->twilio;
$ha->twilio('TwilioMock');
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
    isa_ok($ha->timer,'EV::Timer');
    $ha->clear_timer();
}

# Test alarm reset
{
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
    is(TwilioMock->get_lastcall->{From},$ha->caller_number);
    TwilioMock->reset_lastcall;
}

# Test delayed alarm
{
    my $cv = AnyEvent->condvar;
    my $res = alarm_request('intrusion','Test alarm intrusion',1);
    is($res->code,200,'Status ok');
    is(TwilioMock->get_lastcall,undef,"No lastcall yet");
    ok($ha->has_timer,"Has timer");
    my $timer = AnyEvent->timer (
        after => 3, 
        cb => sub { 
            fail("Did not get twilio call"); 
            $cv->send; 
        }
    );
    my $wait = AnyEvent->idle (cb => sub { 
        if (TwilioMock->get_lastcall) {
            #explain(TwilioMock->get_lastcall);
            ok("Got twilio callback");
            $cv->send;
        }
    });
    $cv->recv;
}

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
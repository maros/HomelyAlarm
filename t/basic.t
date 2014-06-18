# -*- perl -*-

# t/00_load.t - check module loading and create testing directory

use Test::Most tests => 36;

use Plack::Test;
use HTTP::Request::Common;
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);

use_ok( 'App::HomelyAlarm' ); 

my $ha = App::HomelyAlarm->new(
    twilio_sid          => 'SID',
    twilio_authtoken    => 'AUTHTOKEN',
    secret              => 'SECRET',
    caller_number       => '123456789',
);

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
    warn $res->as_string;
}

sub alarm_request {
    my ($path,$message) = @_;
    $message ||= 'empty';
    my $r = HTTP::Request->new('POST','/alarm/'.$path.'?time='.time().'&message='.$message);
    my $key = 'http://localhost'.$r->uri;
    $r->header('X-HomelyAlarm-Signature' => hmac_sha1_hex($key,$ha->secret));
    return $test->request($r);
}
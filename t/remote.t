# -*- perl -*-

# t/remote.t - Test remote server

use Test::Most tests => 36;

use Digest::HMAC_SHA1 qw(hmac_sha1_hex);
use App::HomelyAlarm;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

unless (defined $ENV{ALARM_SERVER}) {
    die("Need to defined ALARM_SERVER env");
}

my $alarm = App::HomelyAlarm->new_with_options;

{
    my $response = alarm_request('run','Rabbit is great. Let\'s have some snu snu. Will we?');
    warn $response->as_string;
}

sub call_request {
    my ($path,$method,$params) = @_;
    $method ||= 'POST';
    $params ||= {};
    $params->{AccountSid} = $alarm->twilio_sid;
    my $uri = $ENV{ALARM_SERVER}.'/call/',$path.'?'.join('&',map { $_.'='.$params->{$_} } sort keys %{$params});
    my $request = HTTP::Request->new($method => $uri);
    $request->header( 'X-Twilio-Signature' => hmac_sha1_hex($uri,$alarm->twilio_authtoken) );
    return $ua->request($request);
}

sub alarm_request {
    my ($path,$message,$timer) = @_;
    $message ||= 'empty';
    my $url = $ENV{ALARM_SERVER}.'/alarm/'.$path.'?time='.time().'&message='.$message;
    $url .= '&timer='.$timer
        if defined $timer;
    my $request = HTTP::Request->new('POST',$url);
    my $digest = hmac_sha1_hex($request->uri,$alarm->secret);
    $request->header('X-HomelyAlarm-Signature' => $digest);
    warn $request->as_string;
    return $ua->request($request);
}
# Load the Module::Install bundled in ./inc/
use strict;
use inc::Module::Install 1.05;
 
my $from = 'lib/App/HomelyAlarm.pm';
 
# Define metadata
name            'App-HomelyAlarm';
all_from        $from;
readme_from     $from;
 
perl_version    '5.014';
 
# Specific dependencies
requires        'Moose'                         => '2.00';
requires        'Twiggy'                        => 0;
requires        'AnyEvent::HTTP'                => 0;
requires        'Digest::HMAC_SHA1'             => 0;
requires        'JSON::XS'                      => 0;
requires        'URI::Escape'                   => 0;
requires        'DBD::SQLite'                   => 0;
requires        'Try::Tiny'                     => 0;
requires        'MIME::Base64'                  => 0;
requires        'Email::Stuffer'                => 0;
requires        'MooseX::App'                   => 1.30;

build_requires  'Test::Most'                    => 0;
build_requires  'Test::NoWarnings'              => 0;
 
author_requires 'Test::Pod'                     => '1.14';
author_requires 'Test::Pod::Coverage'           => '1.04';
author_requires 'Test::Perl::Critic'            => 0;
author_requires 'Module::Install::ReadmeFromPod'=> 0;
 
repository 'git://github.com/maros/HomelyAlarm.git';
 
WriteAll;

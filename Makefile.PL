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
requires        'AnyEvent'                      => 0;
requires        'Twiggy'                        => 0;
requires        'WWW::Twilio::API'              => 0;

build_requires  'Test::Most'                    => 0;
build_requires  'Test::NoWarnings'              => 0;
 
author_requires 'Test::Pod'                     => '1.14';
author_requires 'Test::Pod::Coverage'           => '1.04';
author_requires 'Test::Perl::Critic'            => 0;
author_requires 'Module::Install::ReadmeFromPod'=> 0;
 
repository 'git://github.com/maros/HomelyAlarm.git';
 
WriteAll;

# -*- perl -*-

# t/load.t - load test

use Test::Most tests => 11+1;
use Test::NoWarnings;

use_ok( 'App::HomelyAlarm' ); 
use_ok( 'App::HomelyAlarm::MessageLog' ); 
use_ok( 'App::HomelyAlarm::Recipient' ); 
use_ok( 'App::HomelyAlarm::TwilioTransaction' ); 
use_ok( 'App::HomelyAlarm::Utils' ); 
use_ok( 'App::HomelyAlarm::Role::Recipient' ); 
use_ok( 'App::HomelyAlarm::Role::Server' ); 
use_ok( 'App::HomelyAlarm::Command::Add' ); 
use_ok( 'App::HomelyAlarm::Command::List' ); 
use_ok( 'App::HomelyAlarm::Command::Remove' ); 
use_ok( 'App::HomelyAlarm::Command::Run' ); 


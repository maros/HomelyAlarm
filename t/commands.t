# -*- perl -*-

# t/commands.t - test commands

use Test::Most tests => 13+1;
use Test::NoWarnings;

use strict;
use warnings;

use_ok( 'App::HomelyAlarm' ); 

my $recipients_database = 't/recipients.db';
unlink($recipients_database);

{
    my $recipients;
    
    $recipients = recipients();
    is(scalar(@{$recipients}),0,'Has no recipient');
    
    run_command(
        'add', 
        email => 'test@k-1.com',
    );
    $recipients = recipients();
    is(scalar(@{$recipients}),1,'Has one recipient');
    is($recipients->[0]->email,'test@k-1.com','Email ok');
    
    run_command(
        'add', 
        email => 'test@k-1.com',
        telephone => '+431234',
    );
    $recipients = recipients();
    is(scalar(@{$recipients}),1,'Still has one recipient');
    
    run_command(
        'add', 
        telephone => '+431234',
        only_vacation => 1,
        severity => 'medium',
        only_call => 1,
    );
    
    $recipients = recipients();
    is(scalar(@{$recipients}),2,'Now has two recipients');
    is($recipients->[1]->telephone,'+431234','Telephone ok');
}

{
    my $recipients;
    
    run_command(
        'remove', 
        telephone => '+431234',
    );
    
    $recipients = recipients();
    is(scalar(@{$recipients}),1,'Has one recipient after removal');
    is($recipients->[0]->email,'test@k-1.com','Removed recipient ok');
}

sub recipients {
    return App::HomelyAlarm
        ->new(recipients_database => $recipients_database)
        ->recipients;
}

sub run_command {
    my ($command,%params) = @_;
    
    my $package = 'App::HomelyAlarm::Command::'.ucfirst(lc($command));
    use_ok($package); 
    return $package->new(
        recipients_database => $recipients_database,
        %params,
    )->run;
}

unlink($recipients_database);

#!/usr/bin/perl -w

$|++;

use Test::More tests => 1;

$ENV{CGI_APP_RETURN_ONLY} = 1;
$ENV{SCRIPT_URI} = 'testing.cgi';

use strict;

my ($test_name, $output);

eval
{
my $app = BREADTest->new();
$output = $app->run();
};
$test_name = q%testing that I got a failure with a bad Class::DBI class%;
ok( $@ =~ /Couldn't use No::NonSense::And::Shouldnt::Exist::CDBI class/, $test_name );


package BREADTest;
use base 'CGI::Application';
use CGI::Application::Plugin::BREAD qw( bread_db browse_page_size );

use Class::DBI::Loader;

sub setup
{
    my $self = shift;

    $self->bread_db( [ qw/
            No::NonSense::And::Shouldnt::Exist::CDBI
        / ] );
}

1;
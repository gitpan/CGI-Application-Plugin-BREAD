#!/usr/bin/perl -w

$|++;

use Test::More tests => 1;

$ENV{CGI_APP_RETURN_ONLY} = 1;
$ENV{SCRIPT_URI} = 'testing.cgi';

BEGIN {
    unshift @INC, 't/lib';
}

use strict;

my ($test_name);

eval
{
    my $app = BREADTest->new();
    $app->run();
};

$test_name = q%testing failure b/c i didn't pass any db into play%;
ok( $@, $test_name );

package BREADTest;
use base 'CGI::Application';
use CGI::Application::Plugin::BREAD qw( bread_db browse_page_size );

use Class::DBI::Loader;

sub setup
{
    my $self = shift;
    $self->bread_db( "Hello World!" );
}

1;
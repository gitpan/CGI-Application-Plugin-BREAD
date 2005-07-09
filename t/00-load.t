#!/usr/bin/perl -w

use strict;
use Test::More tests => 1;

use base 'CGI::Application';

BEGIN {
    use_ok( 'CGI::Application::Plugin::BREAD' );
}
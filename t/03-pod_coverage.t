#!/usr/bin/perl -w
use strict;

use Test::More;
eval "use Test::Pod::Coverage 1.04";
if ( $@ )
{
    plan skip_all => "Test::Pod::Coverage 1.04 required" if $@;
} else {
    plan tests => 1;
}

pod_coverage_ok( "CGI::Application::Plugin::BREAD", "CGI::Application::Plugin::BREAD is covered" );

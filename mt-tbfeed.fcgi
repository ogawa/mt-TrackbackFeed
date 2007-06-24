#!/usr/bin/perl -w
use strict;
use lib 'lib';
use MT::Bootstrap;
use MT::App::TrackbackFeed;
use CGI::Fast;

while (my $q = new CGI::Fast) {
    eval {
	my $app = MT::App::TrackbackFeed->new(CGIObject => $q) or die MT::App::TrackbackFeed->errstr;
	local $SIG{__WARN__} = sub { $app->trace($_[0]) };
	MT->set_instance($app);
	$app->init_request(CGIObject => $q) unless $app->{init_request};
	$app->run;
    };
    if ($@) {
	print $q->header, "Got an error: $@";
    }
}

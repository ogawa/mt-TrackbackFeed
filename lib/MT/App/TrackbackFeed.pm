# TrackbackFeed - Generating Trackback feeds.
#
# $Id$
#
# This software is provided as-is. You may use it for commercial or 
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2007 Hirotaka Ogawa

package MT::App::TrackbackFeed;
use strict;

use MT::App;
@MT::App::TrackbackFeed::ISA = qw(MT::App);

use MT::Blog;
use MT::Util qw(encode_xml format_ts ts2epoch);
use MT::TBPing;
use MT::Trackback;
use MT::ConfigMgr;
use MT::I18N;

our $VERSION = '0.01';

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(view => \&view);
    $app->{default_mode} = 'view';
    $app->{template_dir} = 'TrackbackFeed';
    $app;
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
}

sub view {
    my $app = shift;
    my $q = $app->param;
    my $tb;

    my $format = $q->param('format') || 'rss20';

    if (my $tb_id = $q->param('tb_id')) {
	$tb = MT::Trackback->load($tb_id)
	    or return $app->error($app->translate("Invalid Trackback ID '[_1]'", $tb_id));
    } else {
	my $blog_id = $q->param('blog_id')
	    or return $app->error($app->translate("No blog_id"));
	my $blog = MT::Blog->load($blog_id)
	    or return $app->error($app->translate("Loading blog with ID [_1] failed", $blog_id));
	if (my $entry_id = $q->param('entry_id')) {
	    $tb = MT::Trackback->load({ entry_id => $entry_id })
		or return $app->error($app->translate("Entry '[_1]' is not found or trackback-disabled", $entry_id));
	} else {
	}
    }
    $app->generate_tb_feed($format, $tb)
	or return $app->error($app->errstr);

    1;
}

sub generate_tb_feed {
    my $app = shift;
    my ($format, $tb, $lastn) = @_;
    my $feed = {
	feed_title       => $tb->title,
	feed_link        => $tb->url || '',
	feed_description => $tb->description || '',
	feed_language    => MT::ConfigMgr->instance()->DefaultLanguage || 'en-us',
    };

    my %terms = (tb_id => $tb->id, visible => 1);
    my %args = ('sort' => 'created_on', direction => 'descend');
    $args{limit} = $lastn if $lastn;

    my @items;
    my $is_first = 1;
    my $iter = MT::TBPing->load_iter(\%terms, \%args);
    while (my $ping = $iter->()) {
	my $item = {
	    item_title       => encode_xml($ping->title),
	    item_link        => encode_xml($ping->source_url),
	    item_blog_name   => encode_xml($ping->blog_name),
	    item_date_rfc822 => _rfc822date($ping->created_on, $ping->blog_id),
	};
        if ($ping->excerpt) {
	    $item->{item_description} = encode_xml($ping->excerpt);
        }
	push @items, $item;

	if ($is_first) {
	    $feed->{feed_date_rfc822} = $item->{item_date_rfc822};
	    $is_first = 0;
	}
    }
    $feed->{feed_items} = \@items;
    my $res = $app->build_page($format . '.tmpl', $feed)
	or return $app->error($app->translate("Failed to generate [_1] feed", $format));
    my $enc = MT::ConfigMgr->instance()->PublishCharset || 'UTF-8';
    $res = MT::I18N::encode_text($res, $enc, 'utf-8');

    $app->send_http_header('text/xml');
    $app->{no_print_body} = 1;
    $app->{charset} = 'utf-8';
    print $res;
}

sub _rfc822date {
    my ($ts, $blog) = @_;
    $blog = ref $blog ? $blog : MT::Blog->load($blog, { cached_ok => 1 });
    my $so = $blog->server_offset;
    my $partial_hour_offset = 60 * abs($so - int($so));
    my $tz = sprintf("%s%02d%02d", $so < 0 ? '-' : '+', abs($so), $partial_hour_offset);
    format_ts('%a, %d %b %Y %H:%M:%S ' . $tz, $ts, $blog, 'en');
}

1;

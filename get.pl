#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab
# Hint: You need libcrypt-ssleay-perl for this to work with SSL (necessary)

# We subclass WWW::Mechanize to overwrite redirect_ok (to decide whether we
# follow moodle’s redirect or not -- we want to follow local redirects but
# avoid redirects to external pages).
package ZGAgent;
use base 'WWW::Mechanize';

sub redirect_ok {
    my ($self, $req, $resp) = @_;
    my $path = $req->uri()->path();
    # DEBUG
    #print "Deciding about redirect to URL " . $req->uri() . " (path = " . $req->uri()->path() . "\n";
    return ($path =~ /\.(pdf|ps|txt|cpp|zip|tar|bz2)$/);
}

package main;

use strict;
use warnings;
use Net::INET6Glue;
use WWW::Mechanize;
use File::Basename;
use File::Path;
use Data::Dumper;
use Digest::MD5;
use IO::All;
use List::MoreUtils qw(any);
use config;

my $params = shift;
my $update_mode = 0;

if ($params) {
    if ($params eq 'update' or $params eq '-u' or $params eq '--update') {
        $update_mode = 1;
    } elsif ($params eq 'help' or $params eq '-h' or $params eq '--help') {
        print "Syntax: ./get.pl [update]\n";
        exit;
    }
}

my $agent = ZGAgent->new();

if (any { /elearning/ } values %config::urls) {
    print "Logging into moodle...\n";

    # Get loginpage
    $agent->get('https://elearning.uni-heidelberg.de/login/index.php');

    if (!$agent->form_number(2)) {
        print "WARNING: Could not login - Either moodle on elearning.uni-heidelberg.de" .
              "is broken or they changed something in the login process.\n";
    } else {
        # Submit loginform
        $agent->submit_form(
                form_number => 2,
                fields => {
                    username => $config::urz_user,
                    password => $config::urz_pass,
                }
            );
    }
} else {
    print "Skipping moodle login, no URLs configured which use moodle.\n";
}

sub get_digest {
    my $file = shift;

    my $contents = io($file)->binary->all;
    return Digest::MD5->new->add($contents)->hexdigest;
}

sub download_file {
    my ($url, $fn, $target) = @_;

    if (-e $target) {
        # Only update files if started in update mode
        return unless $update_mode;

        my $old_digest = get_digest($target);
        # need to sandbox the call, else it kills the process on fetch error
        eval { $agent->get($url, ':content_file' => $target); };
        unless ($@) {
            my $new_digest = get_digest($target);
            print "\nDocument has changed! Check $target!\n\n" if ($old_digest ne $new_digest);
        } else {
            print "Couldn't load $fn\n";
        }
    } else {
        # New one, let's download
        print "Downloading new Document $fn...\n";

        # need to sandbox the call, else it kills the process on fetch error
        eval { $agent->get($url, ':content_file' => $target); };
        print "Couldn't load $fn\n" if $@;
    }
}

sub get_url {
    my ($name, $url, $target_path, $recurse) = @_;
    my @additional_urls = ();

    if (!$recurse) {
        # first HEAD the URL to see what mime type it has
        $agent->head($url);
        if (!($agent->response->header('content-type') =~ /^text/) && $agent->response->is_success) {
            my $fn = $agent->response->filename;
            # DEBUG
            #print "successfully headed $url, filename is " . $agent->response->filename . "\n";

            download_file($url, $fn, "$target_path/$fn");
        } else {
            get_url($name, $url, $target_path, 1);
        }
        return;
    }

    $agent->get($url);

    # Check all PDFs
    for my $link ($agent->links()) {
        my $abs_link = $link->url_abs()->abs;
        push @additional_urls, $abs_link if $abs_link =~ /resource\/view\.php/;
        next unless $link->url() =~ /\.(pdf|ps|txt|cpp|zip|tar|bz2)$/;

        my $fn = basename $link->url();
        download_file($abs_link, $fn, "$target_path/$fn");
    }

    return unless $recurse;

    get_url($name, $_, $target_path, 0) for (@additional_urls);
}

while (my ($name, $url) = each %config::urls) {
    my $target_path = $config::target . $name;

    mkpath($target_path, { mode => 0755 }) unless (-e $config::target . $name);

    get_url($name, $url, $target_path, 1);
}

print "Finished.\n";

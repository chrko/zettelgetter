#!/usr/bin/env perl
# Hint: You need libcrypt-ssleay-perl for this to work with SSL (necessary)

use strict;
use warnings;
use WWW::Mechanize;
use File::Basename;
use File::Path;
use Data::Dumper;
use Digest::MD5;
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

print "Logging into moodle...\n";

my $agent = WWW::Mechanize->new();
# Get loginpage
$agent->get('https://elearning.uni-heidelberg.de/login/index.php');

if (!$agent->form_number(2)) {
	print "WARNING: Could not login - Either moodle on elearning.uni-heidelberg.de is broken or they changed something in the login process.\n";
} else {
	# Submit loginform
	$agent->submit_form(
			form_number => 2,
			fields => { username => $config::urz_user,
				    password => $config::urz_pass, }
		);
}

sub get_digest {
	my $file = shift;
	open(FILE, $file) or die "Can't open $file";
	binmode(FILE);
	my $digest = Digest::MD5->new->addfile(*FILE)->hexdigest;
	close(FILE);

	return $digest;
}

sub get_url {
	my $name = shift;
	my $url = shift;
	my $target_path = shift;
	my $recurse = shift;
	my @additional_urls = ();

	$agent->get($url);

	# Check all PDFs
	for my $link ($agent->links()) {
		my $abs_link = $link->url_abs()->abs;
		push @additional_urls, $abs_link if $abs_link =~ /resource\/view\.php/;
		next unless $link->url() =~ /\.(pdf|ps|txt|cpp|zip|tar|bz2)$/;
		my $fn = basename $link->url();
		my $target = $target_path."/".$fn;
		if (-e $target) {
			# Only update files if started in update mode
			next unless $update_mode;

			my $old_digest = get_digest($target);
			# need to sandbox the call, else it kills the process on fetch error 
			eval { $agent->get($abs_link, ':content_file' => $target); };
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
			eval { $agent->get($abs_link, ':content_file' => $target); };
			print "Couldn't load $fn\n" if $@;
		}
	}

	for my $link (@additional_urls){
	        get_url($name, $link, $target_path, 0) if $recurse;
	}
}

while ((my $name, my $url) = each %config::urls) {
	my $target_path = $config::target.$name;

	mkpath($target_path, {mode => 0755}) unless (-e $config::target.$name);

	get_url($name, $url, $target_path, 1);
}

print "Finished.\n";

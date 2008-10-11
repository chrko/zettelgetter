#!/usr/bin/env perl
# Hint: You need libcrypt-ssleay-perl for this to work with SSL (necessary)

use strict;
use warnings;
use WWW::Mechanize;
use File::Basename;
use Data::Dumper;
use config;

print "Logging into moodle...\n";

my $agent = WWW::Mechanize->new();
# Get loginpage
$agent->get('https://elearning.uni-heidelberg.de/login/index.php');

# Submit loginform
$agent->submit_form(
		form_number => 2,
		fields => { username => $config::urz_user,
			    password => $config::urz_pass, }
	);

for my $name (keys %config::urls) {
	mkdir $config::target.$name unless (-e $config::target.$name);
	$agent->get($config::urls{$name});

	# Check all PDFs
	for my $link ($agent->links()) {
		next unless $link->url() =~ /\.pdf$/;
		my $fn = basename $link->url();
		if (-e $config::target.$name."/".$fn) {
			# TODO: Update
		} else {
			# New one, let's download
			print "Downloading new PDF $fn...\n";
			$agent->get($link->url(), ':content_file' => $config::target.$name."/".$fn);
		}
	}
}

print "Finished.\n";

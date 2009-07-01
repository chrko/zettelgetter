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

for my $name (keys %config::urls) {
	mkpath($config::target.$name, {mode => 0755}) unless (-e $config::target.$name);
	$agent->get($config::urls{$name});

	# Check all PDFs
	for my $link ($agent->links()) {
		next unless $link->url() =~ /\.(pdf|ps|txt|cpp|zip|tar|bz2)$/;
		my $fn = basename $link->url();
		my $target = $config::target.$name."/".$fn;
		if (-e $target) {
			# Only update files if started in update mode
			next unless $update_mode;

			my $old_digest = get_digest($target);
			$agent->get($link->url(), ':content_file' => $target);
			my $new_digest = get_digest($target);
			print "\nDocument has changed! Check $target!\n\n" if ($old_digest ne $new_digest);
		} else {
			# New one, let's download
			print "Downloading new Document $fn...\n";
			$agent->get($link->url_abs()->abs, ':content_file' => $target);
		}
	}
}

print "Finished.\n";

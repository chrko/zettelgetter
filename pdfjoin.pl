#!/usr/bin/env perl

use strict;
use warnings;
use WWW::Mechanize;
use File::Basename;
use File::Path;
use Data::Dumper;

my $params = shift;

if (!$params or $params eq 'help' or $params eq '-h' or $params eq '--help') {
	print "Syntax: ./pdfjoin.pl <output-file> <URL>\n";
	exit;
}

my $outputfile = $params;

if (-e $outputfile) {
	print "Error: $outputfile already exists.\n";
	exit;
}

my $url = shift;
my $agent = WWW::Mechanize->new();

print "Getting PDFs from $url...\n";

rmtree('temp') if (-e 'temp');
mkdir('temp');

my @queue;
push @queue, $url;

# Get mainpage
$agent->get($url);
for my $link ($agent->links()) {
	if ($link->url_abs()->abs =~ /^$url/ and $link->url_abs()->abs =~ /p_o/) {
		print "Pushing ".$link->url_abs()->abs." to queue\n";
		push @queue, $link->url_abs()->abs;
	}
}

my %saw;
my @unique_queue = grep(!$saw{$_}++, @queue);

for my $c_url (@unique_queue) {
	$agent->get($c_url);

	print "Accessing $c_url...\n";

	# Check all PDFs
	for my $link ($agent->links()) {
		next unless $link->url() =~ /\.pdf$/;
		# Skip MetaPress-crap
		next if $link->url() =~ /MetaPress/;
		my $fn = basename $link->url();
		my $prefix = "temp/";
		my $target = $prefix.$fn;
		my $c = 0;
		if ($target =~ /front/) {
			$prefix .= "00-";
			$target = $prefix.$fn;
		}
		if ($target =~ /back/) {
			$prefix .= "99-";
			$target = $prefix.$fn;
		}
		next if ($target =~ /front|back/ and -e $target);
		$target = "temp/".$fn.".".sprintf("%04d", $c++) while (-e $target);
		# New one, let's download
		print "Downloading PDF $target...\n";
		$agent->get($link->url_abs()->abs, ':content_file' => $target);
	}
}

print "Finished, joining...\n";
system("pdftk temp/* cat output $outputfile");

rmtree('temp');

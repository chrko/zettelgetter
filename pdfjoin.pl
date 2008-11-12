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

print "Getting PDFs from $url...\n";

my $agent = WWW::Mechanize->new();
# Get loginpage
$agent->get($url);

rmtree('temp') if (-e 'temp');
mkdir('temp');

# Check all PDFs
for my $link ($agent->links()) {
	next unless $link->url() =~ /\.pdf$/;
	# Skip MetaPress-crap
	next if $link->url() =~ /MetaPress/;
	my $fn = basename $link->url();
	my $target = "temp/".$fn;
	my $c = 0;
	$target = "temp/".$fn.".".$c++ while (-e $target);
	# New one, let's download
	print "Downloading PDF $target...\n";
	$agent->get($link->url_abs()->abs, ':content_file' => $target);
}

print "Finished, joining...\n";
system("pdftk temp/front* temp/full* temp/back* cat output $outputfile");

rmtree('temp');

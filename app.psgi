#!/usr/bin/perl
use strict;
use warnings;
use Plack::Builder;
use Archive::Zip;
use Data::Dumper;
use List::Util qw(first);
use Plack::MIME;

sub not_found { [404,['Content-type'=>'text/plain'],["notfound"]]; }

my $app = sub { 
	my $env = shift;

	my @pathparts = split '/', $env->{SCRIPT_FILENAME};
	my @zipparts;
	my $zipfile = join("/",@pathparts);
	
	while( @pathparts && not ($zipfile =~ m/\.zip/ && -e $zipfile) ) { 
		unshift @zipparts, pop @pathparts;
		$zipfile = join("/", @pathparts);
	}
	if($zipfile) { 
		my $zip = Archive::Zip->new($zipfile);
		if($zip) { 
			my $membername = join("/",@zipparts);
			if(@zipparts) { 
				my $member = $zip->memberNamed($membername);
				if($member) { 
					return [200,
						[
								'Content-type'=>Plack::MIME->mime_type($member->fileName),
								'Content-length'=>$member->uncompressedSize(),
							
							],[scalar($member->contents)]];
				} else { 
					print STDERR "WARN: $membername not found in $zipfile\n";
					return not_found();
				}
			} else { 
					return [200,
						[
								'Content-type'=>'text/html',
						],
						[	'<html><body><ul>',
							(map { sprintf('<li><a href="%s">%s (%i bytes)</a>', $_->fileName, $_->fileName, $_->uncompressedSize()) } $zip->members),
							'</ul></body></html>'
							]
						];
			}	
		} else { 
			print STDERR "ERROR: $env->{SCRIPT_FILENAME} exists but is broken?\n";
			return [500,['Content-type'=>'text/plain'],['Error opening archive']];
		}
	} else { 
		print STDERR "WARN: $env->{SCRIPT_FILENAME} does not exist\n";
		return not_found();
	}
};

builder {
		$app;
};


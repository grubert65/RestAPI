#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: rest-client.pl
#
#        USAGE: ./rest-client.pl  -config <JSON-encoded config string>
#
#  DESCRIPTION: 
#   performs request and display (eventually decoded) response...
#
#       AUTHOR: Marco Masetti (), marco.masetti@sky.uk
# ORGANIZATION: SKY uk
#      VERSION: 1.0
#      CREATED: 02/06/2018 16:35:33
#===============================================================================
use strict;
use warnings;
use Log::Log4perl   qw( :easy );
use Getopt::Long    qw( GetOptions );
use JSON            qw( decode_json );
use Data::Dumper    qw( Dumper );

use RestAPI ();

Log::Log4perl->easy_init($DEBUG);
$Data::Dumper::Indent = 1;

my $config_as_json;

sub usage {
    return <<EOT
Usage: $0   -config < a JSON-encoded configuration snippet >

EOT
}

GetOptions( "config=s" => \$config_as_json ) or die usage();
die usage() unless ( $config_as_json );

my $config = decode_json( $config_as_json )
    or die ( "Error decoding config params: $!\n");

die "server param is mandatory\n" unless ( $config->{server} );

my $r = RestAPI->new( %$config )
    or die "Error getting a RestAPI object: $!\n";

my $resp = $r->do();
my $raw  = $r->raw();

print "Decoded response:\n";
print Dumper ( $resp );

print "RAW Response:\n";
print $raw."\n";



#!/usr/bin/perl

# A simple UDP socket daemon that sends any received messages directly
# to the sign.  Embedded formatting codes and symbols can be used.
#
# Example:
#    echo "cows go moo #{CALL_DATE_8}" | nc -q1 -u 127.0.0.1 1337

use strict;
use lib '.';
use ezsign;
use IO::Socket;

use constant LISTENPORT => 1337;
use constant SIGNPORT => '/dev/ttyUSB0';



my $sign = ezsign->new(SIGNPORT)
    or die "failed to open sign: $!";

my $server = IO::Socket::INET->new(LocalPort => LISTENPORT,
				   Type      => SOCK_DGRAM,
				   Proto     => 'udp')
    or die "failed to open listener: $!";

print "Now listening on UDP port @{[ LISTENPORT ]}...\n";

while (1) {
    my $line;
    eval {
	$server->recv($line, 1024) or die "Server recv: $!\n";
	chomp $line;
	print "Got message: $line\n";
	$sign->SendTextSimple($line);
    };
    print "Caught error: $@\n" if $@;
}

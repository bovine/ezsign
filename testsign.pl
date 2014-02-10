#!/usr/bin/perl

use lib '.';
use ezsign;
use strict;


#use constant SIGNPORT => 'COM2';
use constant SIGNPORT => '/dev/ttyUSB0';


my $sign = ezsign->new(SIGNPORT);

#$sign->SendTextSimple(mode => 'flash',
#                     text => "testing moo");
#$sign->ClearPriorityText();

$sign->SynchronizeLocalTime();
#$sign->SendTextSimple("foo \x0B8 \x13");
$sign->SendTextSimple("moo #{CALL_DATE_8} #{CALL_TIME}");

#$sign->SoftReset();

exit 0;


use lib '.';
use ezsign;
use strict;


my $sign = ezsign->new("COM1");
#$sign->SendTextSimple(mode => 'flash',
#                     text => "testing moo");
#$sign->ClearPriorityText();

$sign->SynchronizeLocalTime();
$sign->SendTextSimple("foo \x0B8 \x13");

#$sign->SoftReset();

exit 0;


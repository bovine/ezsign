use lib '.';
use ezsign;
use strict;


my $sign = ezsign->new("COM1");
$sign->SendTextSimple("foo");
exit 0;


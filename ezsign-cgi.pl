#!c:\perl\bin\perl.exe

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use lib '.';
use ezsign;
use strict;



my $message = param('text');
my $mode = param('mode') || 'AUTOMODE';
if (!defined $message) {
    printform();
} else {
    my $sign = ezsign->new("COM2");
    $sign->SendTextSimple('text' => $message,
                        'mode' => $mode);
    printsuccess();
}

exit 0;


sub printsuccess {
    print header,
        start_html(-title => 'Scrolling LED Sign',
                   -style => { 'src' => '/ezsign.css' },
                   -BGCOLOR => '#FFFFFF',
                   -TEXT => '#000000' ),
        h1('Successfully sent!'), "\n",
        end_html;
    exit 0;
}


sub printform {
    print header,
        start_html(-title => 'Scrolling LED Sign',
                   -style => { 'src' => '/ezsign.css' },
                   -BGCOLOR => '#FFFFFF',
                   -TEXT => '#000000' ),
        h1('Scrolling LED Sign'), "\n";

    print start_form(-action => script_name),
        "Text: ",
                    textfield(-name => 'text',
                            -default => '',
                            -maxlength => 175,
                            -size => 40),

        p, "(175 chars max)", p,

        "Display Mode: ",
                    popup_menu(-name => 'mode',
                                -values => [ sort keys %ezsign::validmodes ],
                                -default => 'AUTOMODE'
                                ), p,
        submit,
        end_form,
        end_html;
    exit 0;
}

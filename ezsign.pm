#
# $Id: ezsign.pm,v 1.1 2001/11/11 22:40:28 jlawson Exp $
#
# Win32::SerialPort and Device::SerialPort can both be obtained from
#     http://members.aol.com/Bbirthisel/alpha.html

require 5.004;
package ezsign;

use strict;
use vars qw($VERSION $OS_win %validpositions %validmodes);


# The version number of the package is derived from the RCS file version.
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

# Load the appropriate package for serial port communications.
BEGIN {
   $OS_win = ($^O eq "MSWin32") ? 1 : 0;
   if ($OS_win) {
      eval "use Win32::SerialPort";
      die "$@\n" if ($@);
   }
   else {
      eval "use Device::SerialPort";
      die "$@\n" if ($@);
   }
} # End BEGIN


# Although the position is only honored on multi-line displays, it must
# still be specified for all text messages.
%validpositions = (
   'MIDDLE' => "\x20",        # text centered vertically
   'TOP' => "\x22",           # text begins on top line uses all lines except last.
   'BOTTOM' => "\x26",        # text begins on the last top line
   'FILL' => "\x30"           # sign will fill all availabe lines, centering the lines vertically.
   );

# List of all valid display modes that can be used to introduce a piece
# of text onto the display.
%validmodes = (
   'ROTATE' => "\x61",        # Message travels right to left
   'HOLD' => "\x62",          # Message remains stationary
   'FLASH' => "\x63",         # Message remains stationary and flashes.
   'ROLL_UP' => "\x65",       # Previous message is pushed up by a new message.
   'ROLL_DOWN' => "\x66",     # Previous message is pushed down by a new message.
   'ROLL_LEFT' => "\x67",     # Previous message is pushed left by a new message.
   'ROLL_RIGHT' => "\x68",    # Previous message is pushed right by a new message.
   'WIPE_UP' => "\x69",       # New message is wiped over by the previous message from bottom to top.
   'WIPE_DOWN' => "\x6a",
   'WIPE_LEFT' => "\x6b",
   'WIPE_RIGHT' => "\x6c",
   'SCROLL' => "\x6d",
   'AUTOMODE' => "\x6f",      # Various modes are called upon to display
   'ROLL_IN' => "\x70",
   'ROLL_OUT' => "\x71",
   'WIPE_IN' => "\x72",
   'WIPE_OUT' => "\x73",
   'COMPRESSED_ROTATE' => "\x74",
   'TWINKLE' => "\x6e\x30",      # Message will twinkle on the sign.
   'SPARKLE' => "\x6e\x31",      # New message will "sparkle" over the current message.
   'SNOW' => "\x6e\x32",         # Message will "snow" onto the display.
   'INTERLOCK' => "\x6e\x33",    # New message will interlock over the current messsage in alternating rows.
   'SWITCH' => "\x6e\x34",       # Alternating characters "switch" off the sign up and down.
   'SLIDE' => "\x6e\x35",        # New message slides onto the sign one character at a time from right to left.
   'SPRAY' => "\x6e\x36",        # New message sprays across and onto the sign from right to left.
   'STARBURST' => "\x6e\x37",    # "Starbursts" explode the new message onto the sign.
   'WELCOME' => "\x6e\x38",      # the word "Welcome" is written in script across the sign.
   'SLOT_MACHINE' => "\x6e\x39", # slot machine symbols appear randomly across the sign.
   );


# Constructor
sub new {
   my $class = shift || die "no class";
   my $PortName = shift || die "no port name specified";

   my $self = {};
   bless $self, $class;

   # construct the serial port object that is appropriate for the OS.
   if ($OS_win) {
      $self->{'PortObj'} = new Win32::SerialPort ($PortName)
           || die "Can't open $PortName: $^E\n";
   } else {
      $self->{'PortObj'} = new Device::SerialPort ($PortName)
           || die "Can't open $PortName: $^E\n";
   }

   # initialize the port settings.
   $self->{'PortName'} = $PortName;
   $self->{'PortObj'}->baudrate(2400);
   $self->{'PortObj'}->parity("even");
   $self->{'PortObj'}->databits(7);
   $self->{'PortObj'}->stopbits(2);
   $self->{'PortObj'}->write_settings
        || die "Can't change Device_Control_Block: $^E\n";

   return $self;
}

# Internal method use to transmit pre-formatted command strings.
sub _SendRawCommand {    # (self, rawcommand)
   my $self = shift || die "no self";
   my $rawcommand = shift;
   die "no raw command" if !length($rawcommand);

   my $SOH = "\x01";    # start of header
   my $STX = "\x02";    # start of transmission
   my $EOT = "\x04";    # end of transmission

   my $signtype = 'Z';        # any sign type
   my $signaddress = '00';    # broadcast to all

   my $output_string = ( "\x00" x 20 ) . $SOH . $signtype .
         $signaddress . $STX . $rawcommand . $EOT;

   my $count_out = $self->{'PortObj'}->write($output_string);
   warn "write failed\n"         unless ($count_out);
   warn "write incomplete\n"     if ( $count_out != length($output_string) );
}


# Public method used to send new text files to the sign.
sub SendTextFile {    # (self, arghash)
   my $self = shift || die "no self";
   my %arghash = @_;

   # file label to write text into.
   my $filenumber = $arghash{'textfile'};
   $filenumber = "0" if !defined $filenumber;
   die "invalid file label" if !IsValidFileLabel($filenumber);

   # position and size of text on sign.
   my $position = TranslatePosition($arghash{'position'}, 'FILL');
   die "invalid position" if !defined $position;

   # display mode that should be used to draw the text.
   my $displaymode = TranslateMode($arghash{'mode'}, 'AUTOMODE');
   die "invalid mode" if !defined $displaymode;

   # the text that should actually be displayed.
   my $text = $arghash{'text'};
   die "no text supplied" if not defined $text or !length $text;

   # format the command buffer and send it.
   my $ESCAPE = "\x1b";
   my $rawcommand = "A" . $filenumber . $ESCAPE .  $position . $displaymode . $text;
   $self->_SendRawCommand($rawcommand);
}


# Public method used to send new text files to the sign.
# The mode, position, and file number are defaulted.
sub SendTextSimple {  # (self, text)
   my $self = shift || die "no self";
   my $text = shift;

   $self->SendTextFile('text' => $text );
}


# static member to translate a textual "mode" string into the sign-native
# mode identifier that is used within commands sent directly to the sign.
sub TranslateMode {
   my ($modestr, $defaultstr) = @_;
   if (defined $modestr) {
      my $newmode = $validmodes{$modestr} || $validmodes{uc $modestr};
      return $newmode if (defined $newmode);
   }
   if (defined $defaultstr) {
      my $newmode = $validmodes{$defaultstr} || $validmodes{uc $defaultstr};
      return $newmode if (defined $newmode);
   }
   die "no valid display mode possible ($modestr, $defaultstr)";
}


# static member to translate a textual "position" string into the sign-native
# mode identifier that is used within commands sent directly to the sign.
sub TranslatePosition {
   my ($positionstr, $defaultstr) = @_;
   if (defined $positionstr) {
      my $newposition = $validpositions{$positionstr} || $validpositions{uc $positionstr};
      return $newposition if (defined $newposition);
   }
   if (defined $defaultstr) {
      my $newposition = $validpositions{$defaultstr} || $validpositions{uc $defaultstr};
      return $newposition if (defined $newposition);
   }
   die "no valid position possible ($positionstr, $defaultstr)";
}


# static member to test whether a "file label" is valid.  The sign natively
# uses "file labels" to select which storage slot should be used to save a
# message that is being transmitted to it.
sub IsValidFileLabel {
   my $filelabel = shift;
   return ($filelabel =~ m/^[\x20-\x7E]$/);
}


1;


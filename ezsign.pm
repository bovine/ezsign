# Perl package to permit the controlling of Adaptive scrolling LED displays.
# Visit http://www.ams-i.com/ for information about their products.
#
# $Id: ezsign.pm,v 1.3 2001/11/12 02:47:42 jlawson Exp $
#
# Win32::SerialPort and Device::SerialPort can both be obtained from
#     http://members.aol.com/Bbirthisel/alpha.html

require 5.004;
package ezsign;

use strict;
use vars qw($VERSION $OS_win $Debugging
            %validattributes %validpositions %validmodes
            $SOH $STX $ETX $EOT $ESCAPE );


# The version number of the package is derived from the RCS file version.
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

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


# Set to a non-zero value to see a hex-dump of the data being sent.
$Debugging = 0;


# Special command characters used in the formation of commands.
$SOH = "\x01";    # start of header
$STX = "\x02";    # start of transmission
$ETX = "\x03";    # end of text (checksum follows)
$EOT = "\x04";    # end of transmission
$ESCAPE = "\x1b";

# Special attribute characters that may be mixed into messages.
%validattributes = (
   'DOUBLE_HEIGHT_OFF' => "\x05\x30",        # default
   'DOUBLE_HEIGHT_ON' => "\x05\x31",         #              (some models)
   'TRUE_DESCENDERS_OFF' => "\x06\x30",      # default
   'TRUE_DESCENDERS_ON' => "\x06\x31",       #              (some models)
   'WIDE_CHARS_OFF' => "\x11",               # default
   'WIDE_CHARS_ON' => "\x12",


   'CALL_DATE_0' => "\x0B\x30",              # MM/DD/YY (slashes)
   'CALL_DATE_1' => "\x0B\x31",              # DD/MM/YY
   'CALL_DATE_2' => "\x0B\x32",              # MM-DD-YY (dashes)
   'CALL_DATE_3' => "\x0B\x33",              # DD-MM-YY
   'CALL_DATE_4' => "\x0B\x34",              # MM.DD.YY (periods)
   'CALL_DATE_5' => "\x0B\x35",              # DD.MM.YY
   'CALL_DATE_6' => "\x0B\x36",              # MM DD YY (spaces)
   'CALL_DATE_7' => "\x0B\x37",              # DD MM YY
   'CALL_DATE_8' => "\x0B\x38",              # Mmm. DD, YYYY
   'CALL_DATE_9' => "\x0B\x39",              # day of week
   'CALL_TIME' => "\x13",                    # HH:MM

   'NEW_PAGE' => "\x0C",                     # carriage return
   'NEW_LINE' => "\x0D",                     #       (some models)

   'CALL_STRING_X' => "\x10",                # call string (followed by file label)
   'CALL_DOTS_PICTURE_X' => "\x14",          # call picture (followed by file label)

   'NO_HOLD_SPEED' => "\x09",                # when used, there will be virtually no pause following mode presentation.
   'SPEED_SLOWEST' => "\x15",                # speed 1 (slowest)
   'SPEED_LOW' => "\x16",                    # speed 2
   'SPEED_MEDIUM' => "\x17",                 # speed 3
   'SPEED_HIGH' => "\x18",                   # speed 4
   'SPEED_FASTEST' => "\x19",                # speed 5 (fastest)

   'COLOR_RED' => "\x1C\x31",                # text color red
   'COLOR_GREEN' => "\x1C\x32",              # text color green
   'COLOR_AMBER' => "\x1C\x33",              # text color amber
   'COLOR_DIMRED' => "\x1C\x34",             # text color dim red
   'COLOR_DIMGREEN' => "\x1C\x35",           # text color dim green
   'COLOR_BROWN' => "\x1C\x36",              # text color brown
   'COLOR_ORANGE' => "\x1C\x37",             # text color orange
   'COLOR_YELLOW' => "\x1C\x38",             # text color yellow
   'COLOR_RAINBOW1' => "\x1C\x39",           # text color rainbow
   'COLOR_RAINBOW2' => "\x1C\x41",           # text color rainbow
   'COLOR_MIX' => "\x1C\x42",                # text color mixed
   'COLOR_AUTO' => "\x1C\x43",               # text color automatic

   'WIDTH_PROPORTIONAL' => "\x1E\x30",       # proportional spacing (default)
   'WIDTH_FIXED' => "\x1E\x31",              # fixed-width spacing

   'TEMPERATURE_CELSIUS' => "\x08\x1C",      # (some models) temperature in celcius
   'TEMPERATURE_FAHRENHEIT' => "\x08\x1D",   # (some models) temperature in fahrenheit

   'CALL_COUNTER_1' => "\x08\x7A",           # current value of counter 1
   'CALL_COUNTER_2' => "\x08\x7B",           # current value of counter 2
   'CALL_COUNTER_3' => "\x08\x7C",           # current value of counter 3
   'CALL_COUNTER_4' => "\x08\x7D",           # current value of counter 4
   'CALL_COUNTER_5' => "\x08\x7E",           # current value of counter 5

   );


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
   my @rawcommands = @_;
   die "no commands" if !scalar(@rawcommands);

   my $signtype = 'Z';        # any sign type
   my $signaddress = '00';    # broadcast to all
   my $checksum = 1;          # always send checksums

   # Generate the entire command that will be sent.
   my $output_string = ( "\x00" x 20 ) . $SOH . $signtype . $signaddress;
   foreach my $rawcommand (@rawcommands) {
      # Format the actual string that will be sent, including the checksum.
      my $onepart = $STX . $rawcommand . $ETX;
      if ($checksum) {
         $onepart .= ComputeChecksum($onepart);
      }
      $output_string .= $onepart;
   }
   $output_string .= $EOT;

   # Send out the full result.
   my $count_out = $self->{'PortObj'}->write($output_string);
   warn "write failed\n"         unless ($count_out);
   warn "write incomplete\n"     if ( $count_out != length($output_string) );

   # Debugging
   if ($Debugging) {
      $output_string =~ s/(.)/sprintf("%02x ", ord $1)/ges;
      print STDERR "OUTPUT_STRING: $output_string\n";
   }
}

# Static method which returns a 4-digit hexadecimal checksum of a string.
sub ComputeChecksum {
   my $string = shift;
   my $checksum = 0;
   foreach (split(//, $string)) {
      $checksum += ord $_;
   }
   return sprintf("%04X", $checksum);
}

# Public method used to send new pre-formatted text files to the sign.
# This method expects that the text buffer already contains the embedded
# escape codes that indicate the position and mode for the text.
#
#  $sign->SendTextFilePreformatted( 'file' => 'A',
#        'text' => $ESCAPE . "\x20\x62" . "hello world" );
#
sub SendTextFilePreformatted {    # (self, arghash)
   my $self = shift || die "no self";
   my %arghash = @_;

   # file label to write text into.
   my $filenumber = $arghash{'file'};
   $filenumber = "0" if !defined $filenumber;
   die "invalid file label" if !IsValidFileLabel($filenumber);

   # The text that should actually be displayed.
   # Allowable to be undef or empty, when the textfile should be erased.
   my $text = $arghash{'rawtext'};
   $text = "" if !defined $text;

   # format the command buffer and send it.
   my $rawcommand = "A" . $filenumber . $text;
   $self->_SendRawCommand($rawcommand);
}


# Public method used to send new simple text files to the sign.
# Simple text files use the same formatting mode for the entire text.
# If the file/mode/position arguments are omitted then the following
# defaults are assumed:
#      no file specified; destination file '0' (priority message).
#      no display mode; random 'AUTOMODE' should be used.
#      no position; fill screen 'FILL' should be used.
#
#  $sign->SendTextSimple("testing2");
#
#  $sign->SendTextSimple(mode => 'flash', text => "testing moo");
#
#  $sign->SendTextSimple('position' => 'sparkle',
#                       'file' => 'B',
#                       'mode' => 'flash',
#                       'text' => "new message");
#
sub SendTextSimple {    # (self, arghash)
   my $self = shift || die "no self";
   my %arghash;
   if (scalar(@_) > 1 || ref $_ eq 'HASH') {
      %arghash = @_;
   } else {
      $arghash{'text'} = shift;
   }

   # file label to write text into.
   my $filenumber = $arghash{'file'};
   $filenumber = "0" if !defined $filenumber;      # assume priority file
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
   my $rawtext = $ESCAPE .  $position . $displaymode . $text;
   $self->SendTextFilePreformatted( 'file' => $filenumber,
                                    'rawtext' => $rawtext);
}

# static member to translate a textual "mode" string into the sign-native
# mode identifier that is used within commands sent directly to the sign.
sub TranslateMode {
   my ($modestr, $defaultstr) = @_;
   if (defined $modestr) {
      my $newmode = $validmodes{$modestr} || $validmodes{uc $modestr};
      return $newmode if (defined $newmode);
      warn "mode \"$modestr\" was not recognized.";
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
      warn "position \"$positionstr\" was not recognized.";
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


# Erases a text file that was previously sent to the device.
sub ClearTextFile {
   my $self = shift || die "no self";
   my $textfile = shift;
   $self->SendTextFilePreformatted('file' => $textfile, 'rawtext' => '');
}

# Erases the priority text file on the device, allowing other
# text files to be displayed at will.
sub ClearPriorityText {
   my $self = shift || die "no self";
   $self->ClearTextFile('0');
}


# Syncronize the clock on the sign to the current local time (timezone).
sub SynchronizeLocalTime {
   my $self = shift || die "no self";
   my ($min,$hour,$mday,$mon,$year,$wday) = (localtime)[1..6];
   my @rawcommands = (
         "E" . "\x20" . sprintf("%02d%02d", $hour, $min),
         "E" . "\x26" . ($wday + 1) ,
         "E" . "\x3B" . sprintf("%02d%02d%02d", $mon + 1, $mday, $year)
   );
   $self->_SendRawCommand(@rawcommands);
}


# Syncronize the clock on the sign to the current time in GMT.
sub SynchronizeGMT {
   my $self = shift || die "no self";
   my ($min,$hour,$mday,$mon,$year,$wday) = (gmtime)[1..6];
   my @rawcommands = (
         "E" . "\x20" . sprintf("%02d%02d", $hour, $min),
         "E" . "\x26" . ($wday + 1) ,
         "E" . "\x3B" . sprintf("%02d%02d%02d", $mon + 1, $mday, $year)
   );
   $self->_SendRawCommand(@rawcommands);
}


# Returns the contents of a given text file stored on the sign.
#sub ReadTextFile {
#   my $self = shift || die "no self";
#   my $filenumber = shift;
#   $filenumber = "0" if !defined $filenumber;
#   die "invalid file label" if !IsValidFileLabel($filenumber);
#   my $rawcommand = "B" . $filenumber;
#   $self->_SendRawCommand($rawcommand);
#}


1;


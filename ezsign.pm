# Perl package to permit the controlling of Adaptive scrolling LED displays.
# Visit http://www.ams-i.com/ for information about their products.
#
# $Id: ezsign.pm,v 1.5 2001/11/12 07:13:26 jlawson Exp $
#
# Win32::SerialPort and Device::SerialPort can both be obtained from
#     http://members.aol.com/Bbirthisel/alpha.html

require 5.004;
package ezsign;


=head1 NAME

ezsign - Library to permit basic controlling of scrolling alpha-numeric
   LED displays that were produced by Adaptive Micro Systems, Inc.

=head1 SYNOPSIS

   use ezsign;

   my $sign = ezsign->new("COM1");

   # sends priority text message
   $sign->SendTextSimple("hello world");

   # also sends a priority text
   $sign->SendTextSimple(mode => 'flash',
                     text => "testing moo");

   # clears the priority message
   $sign->ClearPriorityText();

   # sync time and send a priority message that displays the time/date.
   $sign->SynchronizeLocalTime();
   $sign->SendTextSimple("current date and time: \x0B8 \x13");


=head1 DESCRIPTION

Please note that only basic communications functionality is currently
offered by this library.

This library was designed and tested with a C<SERIES 300 ALPHA LED SIGN>
which can be cheaply purchased for approximately $175 USD.  Compatibility
with other Adaptive models should be possible but has not been tested.
Although the Adapative communications protocol allows for multiple signs
to be daisy-chained and assigned unique addresses so that they can be
programmed individually or by groups, this library was not designed for
that usage scenario.

The sign has several kilobytes (such as 32kb for the SERIES 300) of persistent
memory that is used to store all of the TEXT files, STRING files, and
DOT graphics.  There are a total of 95 possible "file label" slots, which
are given one-character ASCII names in the range of 0x20 through 0x7E inclusive.
Each of these file labels can be used for one of the three purposes
already mentioned, but changing the designated purpose of a file label
will erase its contents.

The size of each file label is specified at the time its purpose is
configured and the memory used for its storage is taken from the total
amount of persistent memory available on the device.  Message files
cannot be written to any files (other than "0" or "A") until memory is
explicitly allocated for that file label using the Set Memory
Configuration command.

File label "0" is used for Priority messages and is pre-configured to
use a set region of memory outside of the Memory Pool.  When data is
written to the Priority message file, all other text files will stop
being displayed.  When the Priority message file is erased, then normal
display of other text files will resume.  The Priority message file
is limited to 125 characters.  The size, purpose, and operating hours
of the Priority message file cannot be reconfigured.

The normal operational cycle of the sign is to display all TEXT file
labels in sequence, unless there exists a Priority message (stored in
file label "0").  File labels that do not contain TEXT are ignored.
File labels that are configured to only be displayed at certain times
of the date or days of the week are also ignored.


=head1 METHODS

The following methods are currently available:

=over 4

=cut

use strict;
use vars qw($VERSION $OS_win $Debugging
            %validattributes %validpositions %validmodes
            $SOH $STX $ETX $EOT $ESCAPE );


# The version number of the package is derived from the RCS file version.
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

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



=item $sign = ezsign->new($port);

Constructor for the communications object.  Returns a reference to a
ezsign object.  On Windows, the C<$port> will typically be "COM1" or "COM2"
or similar.  On UNIX, C<$port> will be the serial port device filename,
such as "/dev/cua1"

=cut

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

sub _CommandSetText {
   my ($filenumber, $text) = @_;
   return "A" . $filenumber . $text;
}

sub _CommandReadText {
   my $filenumber = shift;
   return "B" . $filenumber;
}

sub _CommandSetMemoryConfiguration {
   my ($filenumber, $filetype, $protected, $size, $extra1, $extra2) = @_;
   if ($filetype eq 'text') {
      return "E" . "\x24" . "A" . ($protected ? 'L' : 'U') .
         sprintf("%04X%02X%02X", $size, $extra1, $extra2);
   } elsif ($filetype eq 'string') {
      return "E" . "\x24" . "B" . ($protected ? 'L' : 'U') .
         sprintf("%04X", $size) . "0000";
   } elsif ($filetype eq 'dots1') {    # monochrome
      return "E" . "\x24" . "C" . ($protected ? 'L' : 'U') .
         sprintf("%04X", $size) . "1000";
   } elsif ($filetype eq 'dots3') {    # three-color
      return "E" . "\x24" . "C" . ($protected ? 'L' : 'U') .
         sprintf("%04X", $size) . "2000";
   } elsif ($filetype eq 'dots8') {    # eight-color
      return "E" . "\x24" . "C" . ($protected ? 'L' : 'U') .
         sprintf("%04X", $size) . "4000";
   }
   return undef;
}

sub _CommandSetTime {
   my ($hour, $min) = @_;
   return "E" . "\x20" . sprintf("%02d%02d", $hour, $min);
}

sub _CommandSetDayOfWeek {
   my $wday = shift;
   return "E" . "\x26" . $wday;
}

sub _CommandSetDate {
   my ($mon, $mday, $year) = @_;
   return "E" . "\x3B" . sprintf("%02d%02d%02d", $mon, $mday, $year);
}

sub _CommandSetTimeFormat {
   my $use24hour = shift;
   return "E" . "\x27" . ($use24hour ? "M" : "S");
}

sub _CommandEnableSpeaker {
   my $enable = shift;
   return "E" . "\x21" . ($enable ? "00" : "FF");
}

sub _CommandGenerateSpeakerTone {
   return undef;        # Not implemented yet.
}

sub _CommandSetRunTimeTable {
   return undef;        # Not implemented yet.
}

sub _CommandSoftReset {
   return "E" . "\x2C";
}

sub _CommandSetRunSequence {
   return undef;        # Not implemented yet.
}

sub _CommandSetRunDayTable {
   return undef;        # Not implemented yet.
}

sub _CommandClearSerialErrorStatusRegister {
   return undef;        # Not implemented yet.
}

sub _CommandSetCounter {
   return undef;        # Not implemented yet.
}

sub _CommandWriteString {
   my ($filenumber, $text) = @_;
   return "G" . $filenumber . $text;
}

sub _CommandReadString {
   my $filenumber;
   return "H" . $filenumber;
}

sub _CommandWriteDotsPicture {
   my ($filenumber, $text) = @_;
   return "I" . $filenumber . $text;
}

sub _CommandReadDotsPicture {
   my $filenumber = shift;
   return "J" . $filenumber;
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
         $onepart .= _ComputeChecksum($onepart);
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
sub _ComputeChecksum {
   my $string = shift;
   my $checksum = 0;
   foreach (split(//, $string)) {
      $checksum += ord $_;
   }
   return sprintf("%04X", $checksum);
}

=item $sign->SendTextSimple(...);

Public method used to send new simple text files to the sign.
Simple text files use the same formatting mode for the entire text.
This method can accept either a single text string, or an argument
hash that allows attributes to optionally be specified for the text.

If the file/mode/position arguments are omitted then the following
defaults are assumed:
     no file specified; destination file '0' (priority message).
     no display mode; random 'AUTOMODE' should be used.
     no position; fill screen 'FILL' should be used.

Note that sending a priority message will prevent all other text messages
stored on the sign from being displayed until the C<ezsign::ClearPriorityText>
method is called.

Examples:

  $sign->SendTextSimple("testing2");

  $sign->SendTextSimple(mode => 'flash', text => "testing moo");

  $sign->SendTextSimple('position' => 'sparkle',
                       'file' => 'B',
                       'mode' => 'flash',
                       'text' => "new message");

=cut

sub SendTextSimple {    # (self, arghash)
   my $self = shift || die "no self";
   my %arghash;
   if (scalar(@_) >= 1 && ref $_ eq 'HASH') {
      %arghash = @_;
   } else {
      $arghash{'text'} = join('', @_);
   }

   # file label to write text into.
   my $filenumber = $arghash{'file'};
   $filenumber = "0" if !defined $filenumber;      # assume priority file
   die "invalid file label" if !_IsValidFileLabel($filenumber);

   # position and size of text on sign.
   my $position = _TranslatePosition($arghash{'position'}, 'FILL');
   die "invalid position" if !defined $position;

   # display mode that should be used to draw the text.
   my $displaymode = _TranslateMode($arghash{'mode'}, 'AUTOMODE');
   die "invalid mode" if !defined $displaymode;

   # the text that should actually be displayed.
   my $text = $arghash{'text'};
   die "no text supplied" if not defined $text or !length $text;

   # format the command buffer and send it.
   my $rawtext = $ESCAPE .  $position . $displaymode . $text;
   $self->SendTextFilePreformatted( 'file' => $filenumber,
                                    'rawtext' => $rawtext);
}


=item $sign->SendTextFilePreformatted( 'file' => $file_label,
                                       'rawtext' => $preformatted_text,
                                       ... );

Public method used to send new pre-formatted text files to the sign.
This method expects that the C<$preformatted_text> already contains the embedded
escape codes that indicate the position, mode, or other display attributes
for the text.

The C<$preformatted_text> argument may be undef or empty if you want to
erase the specified text file, although the C<ezsign::ClearTextFile>
method provides a more convenient way to do this.

The argument C<$file_label> must be a valid single-character file label and
must be large enough to store the entire block of text.  By default, this
method automatically reconfigures allocated memory on the sign so that the
file label will be just large enough for the new block of text.  This
automatic reconfiguring can be supressed by supplying: 'autoconfigure' => 0.

As a side effect of resizing memory, the protection and configured operating
times of the text file will be reset.  If this is not desirable then the
'autoconfigure' option (described above) can be used to supress this behavior.
Alternatively, the new protection that should be used can be explicitly
specified with the 'protected' option.  (There is currently no way to specify
the new operating times of the text file used during autoconfiguring.)

Example:

  # sets the designated file text (with automatic resizing
  # and no protection, by default).
  $sign->SendTextFilePreformatted( 'file' => 'A',
        'rawtext' => "\x1b\x20\x62" . "hello world" );

  # same but does not automatically resize memory.
  $sign->SendTextFilePreformatted( 'file' => 'A',
        'rawtext' => "\x1b\x20\x62" . "hello world",
        'autoconfigure' => 0 );

  # explicitly resizes memory and ensures that the text is
  # protected from being changed via the remote control.
  $sign->SendTextFilePreformatted( 'file' => 'A',
        'rawtext' => "\x1b\x20\x62" . "hello world",
        'autoconfigure' => 1,
        'protected' => 1 );

=cut

sub SendTextFilePreformatted {    # (self, arghash)
   my $self = shift || die "no self";
   my %arghash = @_;

   # determine if we should automatically configure memory for the text.
   my $autoconfigure = $arghash{'autoconfigure'};
   $autoconfigure = 1 if (!defined $autoconfigure);
   my $protected = $arghash{'protected'};

   # file label to write text into.
   my $filenumber = $arghash{'file'};
   $filenumber = "0" if !defined $filenumber;
   die "invalid file label" if !_IsValidFileLabel($filenumber);

   # The text that should actually be displayed.
   # Allowable to be undef or empty, when the textfile should be erased.
   my $text = $arghash{'rawtext'};
   $text = "" if !defined $text;


   # format the command buffer and send it.
   my $rawcommand = _CommandSetText($filenumber, $text);
   if ($autoconfigure && $filenumber ne '0') {
      $rawcommand = _CommandSetMemoryConfiguration(
            $filenumber, 'text', $protected, length $text, 0, 0) .
            $rawcommand;
   }
   $self->_SendRawCommand($rawcommand);
}




# static member to translate a textual "mode" string into the sign-native
# mode identifier that is used within commands sent directly to the sign.
sub _TranslateMode {
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
sub _TranslatePosition {
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
sub _IsValidFileLabel {
   my $filelabel = shift;
   return ($filelabel =~ m/^[\x20-\x7E]$/);
}


=item $sign->ClearTextFile($filelabel);

Erases a text file that was previously sent to the device.

Examples:

  $sign->ClearTextFile("A");

=cut

sub ClearTextFile {
   my $self = shift || die "no self";
   my $textfile = shift;
   $self->SendTextFilePreformatted('file' => $textfile, 'rawtext' => '');
}



=item $sign->ClearPriorityText();

Erases the priority text file on the device, allowing other
text files to be displayed at will.  This method is a shorthand for calling
C<ezsign::ClearTextFile> with an argument of "0".

Examples:

  $sign->ClearPriorityText();

=cut

sub ClearPriorityText {
   my $self = shift || die "no self";
   $self->ClearTextFile('0');
}



=item $sign->SynchronizeLocalTime();

Syncronize the clock on the sign to the current local time (timezone).
The sign uses the time and date to schedule which messages should be
displayed on specified days of the week and/or hours of the day.  The
current time and date can also be incorporated into text messages by
placing the appropriate escape codes within your text messages.

=cut

sub SynchronizeLocalTime {
   my $self = shift || die "no self";
   my ($min,$hour,$mday,$mon,$year,$wday) = (localtime)[1..6];
   my @rawcommands = (
         _CommandSetTime($hour, $min),
         _CommandSetDayOfWeek($wday + 1) ,
         _CommandSetDate($mon + 1, $mday, $year)
   );
   $self->_SendRawCommand(@rawcommands);
}


=item $sign->SynchronizeGMT();

Syncronize the clock on the sign to the current time in GMT.  See
C<ezsign::SynchronizeLocalTime> for more information.

=cut
sub SynchronizeGMT {
   my $self = shift || die "no self";
   my ($min,$hour,$mday,$mon,$year,$wday) = (gmtime)[1..6];
   my @rawcommands = (
         _CommandSetTime($hour, $min),
         _CommandSetDayOfWeek($wday + 1) ,
         _CommandSetDate($mon + 1, $mday, $year)
   );
   $self->_SendRawCommand(@rawcommands);
}


=item $sign->SoftReset();

Sends a soft-reset to the sign.  No persisted data is erased in a
soft-reset.  Immediately following the reset, the sign will display its
ROM version, memory size, and other factory-determined values, before
resuming display of its text files.  Performing a soft-reset will cause
the sign to forget the current time and date.  It is not normally necessary
to invoke this method.

=cut
sub SoftReset {
   my $self = shift || die "no self";
   my $rawcommand = _CommandSoftReset();
   $self->_SendRawCommand($rawcommand);
}



# Returns the contents of a given text file stored on the sign.
#sub ReadTextFile {
#   my $self = shift || die "no self";
#   my $filenumber = shift;
#   $filenumber = "0" if !defined $filenumber;
#   die "invalid file label" if !_IsValidFileLabel($filenumber);
#   my $rawcommand = _CommandReadText($filenumber);
#   $self->_SendRawCommand($rawcommand);
#}



1;


=back

=head1 SEE ALSO

See F<http://www.ams-i.com/> for details about the Adaptive product lines
and other technical specifications about the communications protocol used
with their products.

=head1 COPYRIGHT

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


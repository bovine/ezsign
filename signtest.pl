# Win32::SerialPort can be obtained from http://members.aol.com/Bbirthisel/alpha.html

require 5.003;
use Win32::SerialPort qw( :STAT 0.19 );
use strict;


# Although the position is only honored on multi-line displays, it must
# still be specified for all text messages.
my %validpositions = (
   'MIDDLE' => "\x20",        # text centered vertically
   'TOP' => "\x22",           # text begins on top line uses all lines except last.
   'BOTTOM' => "\x26",        # text begins on the last top line
   'FILL' => "\x30"           # sign will fill all availabe lines, centering the lines vertically.
   );

# List of all valid display modes that can be used to introduce a piece
# of text onto the display.
my %validmodes = (
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



my $PortObj = OpenPort("COM1");
SendTextSimple($PortObj, "i dreamt i saw a moocow jump across the moon");
exit 0;




sub OpenPort {
   my $PortName = shift || "COM1";

   my $PortObj = new Win32::SerialPort ($PortName)
        || die "Can't open $PortName: $^E\n";

   $PortObj->baudrate(2400);
   $PortObj->parity("even");
   $PortObj->databits(7);
   $PortObj->stopbits(2);
   $PortObj->write_settings
        || die "Can't change Device_Control_Block: $^E\n";

   return $PortObj;
}

sub SendRawCommand {
   my $PortObj = shift || die "no port object";
   my $rawcommand = shift;
   die "no raw command" if !length($rawcommand);

   my $SOH = "\x01";    # start of header
   my $STX = "\x02";    # start of transmission
   my $EOT = "\x04";    # end of transmission

   my $signtype = 'Z';        # any sign type
   my $signaddress = '00';    # broadcast to all

   my $output_string = ( "\x00" x 20 ) . $SOH . $signtype .
         $signaddress . $STX . $rawcommand . $EOT;

   my $count_out = $PortObj->write($output_string);
   warn "write failed\n"         unless ($count_out);
   warn "write incomplete\n"     if ( $count_out != length($output_string) );
}


sub SendTextSimple {  # (PortObj, text)
   my $PortObj = shift || die "no port object";
   my $text = shift;

   SendTextFile($PortObj, 'text' => $text);
}

sub SendTextFile {    # (PortObj, arghash)
   my $PortObj = shift || die "no port object";
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
   SendRawCommand($PortObj, $rawcommand);

   $rawcommand =~ s/(.)/sprintf('%02X ', ord $1)/ge;
   print $rawcommand;
}

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


sub IsValidFileLabel {
   my $filelabel = shift;
   return ($filelabel =~ m/^[\x20-\x7E]$/);
}




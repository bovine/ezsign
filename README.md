ezsign
======

This is a Perl module that provides very basic communications
functionality with wall-mounted LED signs capable of displaying
single-line alpha-numeric text.


Sign Compatibilty
-----------------

This library was designed and tested with the following signs:

* Series 300 Alpha LED Sign, by Adaptive Micro Systems (Milwaukee, WI)
* Model 320C Alpha LED Sign, by Spectrum Corporation (Houston, TX)

Compatibility with other sign models may be possible but has not been
tested.  Although the communications protocol allows for multiple
signs to be daisy-chained (via RS485) and assigned unique addresses so
that they can be programmed individually or by groups, this library
was only designed for single device communication (vs RS232).


Sign Hardware Overview
----------------------

The sign has several kilobytes (typically as 32kb) of persistent
memory that is used to store all of the TEXT files, STRING files, and
DOT graphics.  There are a total of 95 possible "file label" slots,
which are given one-character ASCII names in the range of 0x20 through
0x7E inclusive.  Each of these file labels can be used for one of the
three purposes already mentioned, but changing the designated purpose
of a file label will erase its contents.

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


Library Dependencies
--------------------

In addition to Perl 5, you will need to install one of the following
serial port modules from CPAN, depending on your operating system:

* Win32::SerialPort
* Device::SerialPort

The example web interface requires the following Perl module:

* CGI



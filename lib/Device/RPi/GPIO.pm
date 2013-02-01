package Device::RPi::GPIO;

use strict;
use warnings;

use Carp;

BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    $VERSION     = '0.01';
    @ISA         = qw(Exporter);
    #Give a hoot don't pollute, do not export more than needed by default
    @EXPORT      = qw();
    @EXPORT_OK   = qw();
    %EXPORT_TAGS = ();
}

sub new {
    my($class, %parameters) = @_;

    my $self = bless({EXPORTED => {}}, ref ($class) || $class);

    #note the pin numbers start at 1 and arrays start at 0
    $self->{PIN}  = [undef, undef, undef, 0, undef, 1, undef, 4, 14, undef, 15, 17, 18, 21, undef, 22, 23, undef, 24, 10, undef, 9, 25, 11, 8, undef, 7];
    $self->{BCM}  = [0, 1, 4, 7, 8, 9, 10, 11, 14, 15, 17, 18, 21, 22, 23, 24, 25];
    $self->{MODE} = 'PIN';
    $self->{PATH} = '/sys/class/gpio/';

    if(defined($parameters{PATH})) {
	unless (-e $parameters{PATH} && -d $parameters{PATH}) {
	    croak 'Invalid PATH parameter';
	}
	$self->{PATH} = $parameters{PATH};
	unless($self->{PATH} =~ m/\/\z/) {
	    $self->{PATH} .= '/';
	}
    }

    if(defined($parameters{MODE})) {
	unless ($parameters{MODE} =~ m/^(PIN|BCM)\z/i ) {
	    croak "Invalid MODE parameter";
	}
	$self->{MODE} = uc($parameters{MODE});
    }

    if(defined($parameters{PIN})) {
	unless(ref $parameters{PIN} eq 'ARRAY') {
	    croak "Invalid PIN parameter";
	}
	foreach(@{$parameters{PIN}}) {
	    unless(!defined $_ || $_ =~ m/^\d+\z/) {
		croak 'Invalid PIN parameter';
	    }
	}
	$self->{PIN} = $parameters{PIN};
    }

    if(defined($parameters{BCM})) {
	unless(ref $parameters{BCM} eq 'ARRAY') {
	    croak "Invalid BCM parameter";
	}
	foreach(@{$parameters{BCM}}) {
	    unless(defined $_ && $_ =~ m/^\d+\z/) {
		croak 'Invalid BCM parameter';
	    }
	}
	$self->{BCM} = $parameters{BCM};
    }

    return $self;
}

sub setup {
    my($self, $channel, $direction) = @_;

    $channel = $self->_map_channel($channel);

    #check $direction
    unless(defined($direction) && $direction =~ m/^(IN|OUT)\z/i) {
	croak 'Invalid direction used for GPIO setup';
    }
    $direction = lc($direction);

    #unexport if gpio definition exists
    if(-e $self->{PATH}.'gpio'.$channel) {
	$self->remove($channel);
    }

    #export gpio definition
    open my $fh, '>', $self->{PATH}.'export'
	or die 'setup error opening export';
    print $fh $channel;
    close $fh;

    #set gpio direction
    open $fh, '>', $self->{PATH}.'gpio'.$channel.'/direction'
	or die 'setup error opening gpio direction';
    print $fh $direction;
    close $fh;

    #one last sanity check
    unless(-e $self->{PATH}.'gpio'.$channel) {
	die 'setup did not manage to configure the gpio channel';
    }

    $self->{EXPORTED}{$channel} = $direction;
}

sub output {
    my($self, $channel, $value) = @_;

    $channel = $self->_map_channel($channel);

    #check $channel is exported and set to output mode
    unless(defined($self->{EXPORTED}{$channel}) && $self->{EXPORTED}{$channel} eq 'out') {
	croak 'Tried to output on invalid channel';
    }

    #validate output
    $value = (defined($value) && $value)? 1 : 0;

    #set the $value on gpio channel
    open my $fh, '>', $self->{PATH}.'gpio'.$channel.'/value'
	or die 'output error opening gpio value';
    print $fh $value;
    close $fh;
}

sub input {
    my($self, $channel) = @_;

    $channel = $self->_map_channel($channel);

    #check $channel is exported and set to input mode
    unless(defined($self->{EXPORTED}{$channel}) && $self->{EXPORTED}{$channel} eq 'in') {
	croak 'Tried to input on invalid channel';
    }

    open my $fh, '<', $self->{PATH}.'gpio'.$channel.'/value'
	or die 'input unable to open gpio value';
    my $value = <$fh>;
    close $fh;
    return $value;
}

sub pull {
    my($self, $channel, $direction) = @_;

    $channel = $self->_map_channel($channel);

    #check $direction
    unless(defined($direction) && $direction =~ m/^(UP|DOWN|TRI)\z/i) {
	croak 'Invalid direction used for GPIO pull';
    }
    $direction = lc($direction);

    system('gpio', '-g', 'mode', $channel, $direction) == 0
	or die "Unable to execute the gpio command (install the wiringPi library?): $!";
}

sub remove {
    my($self, $channel) = @_;

    if(defined($channel) && $channel =~ m/^\d+\z/) {
	$channel = $self->_map_channel($channel);
	
	unless(-e $self->{PATH}.'gpio'.$channel) {
	    croak 'Invalid remove channel';
	}

	open my $fh, '>', $self->{PATH}.'unexport'
	    or die 'Erorr remove could not open unexport';
	print $fh $channel;
	close $fh;

	unless(!-e $self->{PATH}.'gpio'.$channel) {
	    die 'Error remove could not unexport gpio'.$channel;
	}
    }
    elsif(defined($channel) && $channel =~ m/^ALL\z/i) {
	foreach(keys %{$self->{EXPORTED}}) {
	    $self->remove($_);
	    delete $self->{EXPORTED}{$_};
	}
    }
    else {
	croak 'Invalid remove parameter';
    }
}

sub _map_channel {
    my($self, $channel) = @_;
    unless(defined($channel) && $channel =~ /^\d+\z/) {
        croak 'The channel sent was not an integer';
    }

    if($self->{MODE} eq 'BCM') {
        unless(grep $_ == $channel, @{$self->{BCM}}) {
            croak 'The BCM channel sent is invalid on a Raspberry Pi';
        }
    }
    else {
        $channel = $self->{PIN}[$channel];
        unless(defined($channel)) {
            croak 'The PIN channel sent is invalid on a Raspberry Pi';
        }
    }

    return $channel;
}

sub DESTROY {
    my ($self) = @_;
    local $!;
    $self->remove('ALL');
}

1;
__END__

=head1 NAME

Device::RPi::GPIO - GPIO Access for Raspberry Pi

=head1 SYNOPSIS

    use Device::RPi::GPIO;

    my $gpio = Device::RPi::GPIO->new(MODE => 'PIN');
    $gpio->setup(11, 'IN');
    $gpio->setup(12, 'OUT');

    $gpio->pull(11, 'UP');

    my $value = $gpio->input(11);
    print "INPUT 11 -> $value -> OUTPUT 12\n";
    $gpio->output(12, $value);


=head1 DESCRIPTION

This module aims to provide a simple Perl interface to the Raspberry Pi's
GPIO pins. It is not particularly high performance (using the /sys interface)
and not particularly powerful, but it has no external dependencies and can
get the job done in many common cases.

As an alternative, you may consider using the Perl interface to the wiringPi
library. However, the bindings are currently hopelessly rusty and the Wiring
abstraction may not make much sense in Perl.

As another alternative, you may use the L<Device::BCM2835> module. However,
it also has an external dependency, requires root permissions and to actually
use it, you must study the BCM2835 chip datasheet.


=head1 USAGE

=over 4

=item new(MODE => $mode, PIN => @pin, BCM => @bcm)

Create new Device::RPi:GPIO instance.

B<PATH> - Path to gpio
(Default: C</sys/class/gpio/>)

B<MODE> - GPIO channel pin numbering method:
(Default: C<'PIN'>)

=over 4

C<'PIN'>: Raspberry Pi's official GPIO pin numbers.

C<'BCM'>: Raspberry Pi's Broadcom GPIO designation.

=back

B<PIN> - Set a custom Raspberry Pi PIN -> BCM map
(Note: the first item shall be undef as the RPi numbering starts at pin 1)

B<BCM> - Set a custom list of BCM pins available as RPi GPIO pins

Returns: Device::RPi::GPIO instance.


=item setup($channel, $direction)

Register a GPIO channel and set its direction.

B<$channel> is pin number (according to mode)

B<$direction> shall be either C<'IN'> or C<'OUT'>


=item input($channel)

Get current electrical value on pin of GPIO channel B<$channel>.

Returns: TTL value (0 or 1).


=item output($channel, $value)

Set electrical value on pin of GPIO channel B<$channel>.

B<$value> shall be TTL digital value 0 (ground) or 1 (Vcc)


=item pull($channel, $direction)

Configure internal resistor attached to the pin of GPIO channel
B<$channel>. This makes sense only for channels in the input direction
and it is useful for channels that may alternately be driven and have
nothing connected to the pins.

B<$direction> shall be either
C<'UP'> (to enable internal pull-up that will set the pin to "1 by default"),
C<'DOWN'> (to enable internal pull-down that will set the pin to "0 by default")
or C<'TRI'> (to leave the pin in "floating state" where its value is undefined
when nothing drives the pin).

For example, if a button connects a pin to Vcc (1), you will wanto to enable
the pin's internal pull-down resistor that will force the pin to ground (0)
while the button is not pressed.

As current kernels do not provide a /sys interface to setup the internal
resistors, this specific function depends on the L<gpio(1)> tool that is
distributed with the B<wiringPi> library.


=item remove($channel)

Unregister the GPIO channel B<$channel>. B<$channel> may be C<'ALL'>
to unregister all channels.

=back

=head1 BUGS

If there are none I will be surprised and always room for improvement

=head1 SUPPORT

#raspberrypi on FreeNode IRC

=head1 AUTHOR

    NucWin
    nucwin@gmail.com

    Petr Baudis
    pasky@ucw.cz

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1), gpio(1), L<Device::BCM2835>, L<wiringPi>.

https://github.com/nucwin/perl-rpi-gpio

https://github.com/pasky/perl-rpi-gpio

=cut

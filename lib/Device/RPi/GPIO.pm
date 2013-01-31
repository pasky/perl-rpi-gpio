package Device::RPi::GPIO;
use strict;
use warnings;

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
	if(-e $parameters{PATH} && -d $parameters{PATH}) {
	    $self->{PATH} = $parameters{PATH};
	    unless($self->{PATH} =~ m/\/\z/) {
		$self->{PATH} .= '/';
	    }
	}
	else {
	    warn 'Invalid PATH parameter';
	}
    }

    if(defined($parameters{MODE})) {
	if($parameters{MODE} =~ m/^(PIN|BCM)\z/i ) {
	    $self->{MODE} = uc($parameters{MODE});
	}
	else {
	    warn "Invalid MODE parameter";
	}
    }

    if(defined($parameters{PIN})) {
	if(ref $parameters{PIN} eq 'ARRAY') {
	    my $pass = 1;
	    foreach(@{$parameters{PIN}}) {
		unless(!defined $_ || $_ =~ m/^\d+\z/) {
		    warn 'Invalid PIN parameter';
		    $pass--;
		}
	    }
	    $self->{PIN} = $parameters{PIN} if($pass);
	}
	else {
	    warn "Invalid PIN parameter"
	}
    }

    if(defined($parameters{BCM})) {
	if(ref $parameters{BCM} eq 'ARRAY') {
	    my $pass = 1;
	    foreach(@{$parameters{BCM}}) {
		unless(defined $_ && $_ =~ m/^\d+\z/) {
		    warn 'Invalid BCM parameter';
		    $pass--;
		}
	    }
	    $self->{BCM} = $parameters{BCM} if($pass);
	}
	else {
	    warn "Invalid BCM parameter"
	}
    }

    return $self;
}

sub setup {
    my($self, $channel, $direction) = @_;

    #check $channel
    $channel = $self->validate($channel);
    unless(defined($channel)) {
	warn 'Invalid channel used for GPIO setup';
	return 0;
    }

    #check $direction
    unless(defined($direction) && $direction =~ m/^(IN|OUT)\z/i) {
	warn 'Invalid direction used for GPIO setup';
	return 0;
    }
    $direction = lc($direction);

    #unexport if gpio definition exists
    if(-e $self->{PATH}.'gpio'.$channel) {
	$self->remove($channel);
    }

    #export gpio definition
    if(open my $fh, '>', $self->{PATH}.'export') {
	print $fh $channel;
	close $fh;
    }
    else {
	warn 'setup error opening export';
	return 0;
    }

    #set gpio direction
    if(open my $fh, '>', $self->{PATH}.'gpio'.$channel.'/direction') {
	print $fh $direction;
	close $fh;
    }
    else {
	warn 'setup error opening gpio direction';
	return 0;
    }

    #one last sanity check
    unless(-e $self->{PATH}.'gpio'.$channel) {
	warn 'setup did not manage to configure the gpio channel';
	return 0;
    }

    $self->{EXPORTED}{$channel} = $direction;
    return 1;
}

sub output {
    my($self, $channel, $value) = @_;

    #check $channel
    $channel = $self->validate($channel);
    unless(defined($channel)) {
	warn 'Invalid channel used for GPIO output';
	return 0;
    }

    #check $channel is exported and set to output mode
    unless(defined($self->{EXPORTED}{$channel}) && $self->{EXPORTED}{$channel} eq 'out') {
	warn 'Tried to output on invalid channel';
	return 0;
    }

    #validate output
    $value = (defined($value) && $value)? 1 : 0;

    #set the $value on gpio channel
    if(open my $fh, '>', $self->{PATH}.'gpio'.$channel.'/value') {
	print $fh $value;
	close $fh;
    }
    else {
	warn 'output error opening gpio value';
	return 0;
    }

    return 1;
}

sub input {
    my($self, $channel) = @_;

    #check $channel
    $channel = $self->validate($channel);
    unless(defined($channel)) {
	warn 'Invalid channel used for GPIO setup';
	return undef;
    }

    #check $channel is exported and set to input mode
    unless(defined($self->{EXPORTED}{$channel}) && $self->{EXPORTED}{$channel} eq 'in') {
	warn 'Tried to input on invalid channel';
	return undef;
    }

    if(open my $fh, '<', $self->{PATH}.'gpio'.$channel.'/value') {
	my $value = <$fh>;
	close $fh;
	return $value;
    }
    else {
	warn 'input unable to open gpio value';
	return undef;
    }
}

sub validate {
    my($self, $channel) = @_;
    unless(defined($channel) && $channel =~ /^\d+\z/) {
        warn 'The channel sent was not an integer';
        return undef;
    }

    if($self->{MODE} eq 'BCM') {
        unless(grep $_ == $channel, @{$self->{BCM}}) {
            warn 'The BCM channel sent is invalid on a Raspberry Pi';
            return undef;
        }
    }
    else {
        $channel = $self->{PIN}[$channel];
        unless(defined($channel)) {
            warn 'The PIN channel sent is invalid on a Raspberry Pi';
            return undef;
        }
    }

    return $channel;
}

sub remove {
    my($self, $channel) = @_;

    if(defined($channel) && $channel =~ m/^\d+\z/) {
	#check $channel
	$channel = $self->validate($channel);
	unless(defined($channel)) {
	    warn 'Invalid remove parameter';
	    return 0;
	}
	
	unless(-e $self->{PATH}.'gpio'.$channel) {
	    warn 'Invalid remove channel';
	    return 0;
	}

	if(open my $fh, '>', $self->{PATH}.'unexport') {
	    print $fh $channel;
	    close $fh;
	}
	else {
	    warn 'Erorr remove could not open unexport';
	    return 0;
	}

	unless(!-e $self->{PATH}.'gpio'.$channel) {
	    warn 'Error remove could not unexport gpio'.$channel;
	    return 0;
	}

	return 1;
    }
    elsif(defined($channel) && $channel =~ m/^ALL\z/i) {
	foreach(@{keys $self->{EXPORTED}}) {
	    if($self->remove($_)){
		delete $self->{EXPORTED}{$_};
	    }
	    else {
		warn 'Error remove could not unexport gpio'.$_
	    }
	}
	return %{$self->{EXPORTED}} ? 0 : 1;
    }
    else {
	warn 'Invalid remove parameter';
	return 0;
    }
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

Returns: 1 on success, 0 on fail.


=item input($channel)

Get current electrical value on pin of GPIO channel B<$channel>.

Returns: 0 or 1 on success, undef if failed.


=item output($channel, $value)

Set electrical value on pin of GPIO channel B<$channel>.

B<$value> shall be TTL digital value 0 (ground) or 1 (Vcc)

Returns: 1 on success, 0 on fail.


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

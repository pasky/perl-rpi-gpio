# -*- perl -*-

# t/002_params.t - check module loading when listing custom parameters

use Test::More tests => 3;

BEGIN { use_ok( 'Device::RPi::GPIO' ); }

my $object;
eval {
    $object = Device::RPi::GPIO->new(
	PATH => '/sys/class/gpio/',
	MODE => 'PIN',
	PIN  => [undef, undef, undef, 0, undef, 1, undef, 4, 14, undef, 15, 17, 18, 21, undef, 22, 23, undef, 24, 10, undef, 9, 25, 11, 8, undef, 7],
	BCM  => [0, 1, 4, 7, 8, 9, 10, 11, 14, 15, 17, 18, 21, 22, 23, 24, 25],
    );
};
ok(not $@);
isa_ok ($object, 'Device::RPi::GPIO');

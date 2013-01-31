# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Device::RPi::GPIO' ); }

my $object = Device::RPi::GPIO->new ();
isa_ok ($object, 'Device::RPi::GPIO');



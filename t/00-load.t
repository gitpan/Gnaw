#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Gnaw' );
}

diag( "Testing Gnaw $Gnaw::VERSION, Perl $], $^X" );

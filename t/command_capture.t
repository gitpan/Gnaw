

use Test::More tests=>4;

use Gnaw;

my $grammar;




my $string;

my $callback = sub {$string = shift(@_);};


$grammar = match(capture(
		series( lit('b'), set('aeiou'), lit('b') )  ,
		$callback
		)
	);


$string='';
ok( 1==$grammar->('alice bob charlie'), "capture confirm match");
ok( $string eq 'bob', "capture confirm capture");

$string='';
ok( 0==$grammar->('alice bxb charlie'), "capture confirm no match");
ok( $string eq '', "capture confirm no capture");

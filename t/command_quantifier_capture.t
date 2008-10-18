

use Test::More tests=>30;

use Gnaw;

my $grammar;

my $string='';

my $callback = sub {
	$string = shift(@_);
};

#die "\n\nstring is '$string'\n\n";


$grammar = match(capture(quantifier('t', lit('a'), 3,7), $callback));

$string = '';
ok( 1==$grammar->('bcdefaaaaahjklm'), "match 1.1");
ok( $string eq 'aaa', "check capture 1.1");


$string = '';
ok( 1==$grammar->('abcdefaaaaaaaaaaaaaaahjklm'), "match 1.2");
ok( $string eq 'aaa', "check capture 1.2");

$string = '';
ok( 0==$grammar->('abcdefaahjklm'), "match 1.3");
ok( $string eq '', "check capture 1.3");

 
$grammar = match(capture(quantifier('t', lit('a'), 3), $callback));

$string = '';
ok( 1==$grammar->('abcdefaaaaahjklm'), "match 2.1");
ok( $string eq 'aaa', "check capture 2.1");


$string = '';
ok( 0==$grammar->('abcdefaahjklm'), "match 2.2");
ok( $string eq '', "check capture 2.2");


$grammar = match(capture(quantifier('g', lit('a'), 3), $callback));

$string = '';
ok( 1==$grammar->('abcdefaaaaahjklm'), "match 3.1");
ok( $string eq 'aaaaa', "check capture 3.1");

$string = '';
ok( 0==$grammar->('abcdefaahjklm'), "match 3.2");
ok( $string eq '', "check capture 3.2");


$grammar = match(capture(quantifier(lit('a'), 3), $callback));

$string = '';
ok( 1==$grammar->('abcdefaaaaahjklm'), "match 4.1");
ok( $string eq 'aaaaa', "check capture 4.1");

$string = '';
ok( 0==$grammar->('abcdefaahjklm'), "match 4.2");
ok( $string eq '', "check capture 4.2");

$grammar = match(capture(quantifier(lit('a'), 's'), $callback));

$string = '';
ok( 1==$grammar->('bcdefaaaaaaaaahjklm'), "match 5.1");
ok( $string eq 'aaaaaaaaa', "check capture 5.1");


$string = '';
ok( 0==$grammar->('xbcdeffghhjklm'), "match 5.2");
ok( $string eq '', "check capture 5.2");

$grammar = match(capture(quantifier(lit('a'), '+'), $callback));

$string = '';
ok( 1==$grammar->('bcdefaaaaaaaaaaahjklm'), "match 6.1");
ok( $string eq 'aaaaaaaaaaa', "check capture 6.1");


$string = '';
ok( 0==$grammar->('xbcdeffghhjklm'), "match 6.2");
ok( $string eq '', "check capture 6.2");




$grammar = match(capture(quantifier(lit('a'), '*'), $callback));
$string = '';
ok( 1==$grammar->('abcdefaaaaahjklm'), "match 7.1");
ok( $string eq '', "check capture 7.1");


$string = '';
ok( 1==$grammar->('xbcdeffghhjklm'), "match 7.2");
ok( $string eq '', "check capture 7.2");

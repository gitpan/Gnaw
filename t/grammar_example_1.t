
use Test::More tests=>12;

use Gnaw;

my $grammar;


sub greeting {alternation( lit('hello'), lit('howdy'), lit('hi'), lit('hey') )}

sub name { alternation( lit('alice'), lit('bob'), lit('charlie'), lit('dave'), lit('eve') ) }

sub greet_someone { series( greeting, name ) }


$grammar = match(greet_someone);


ok(1 == $grammar->('hello dave'), 	"1.1 match");
ok(1 == $grammar->('hi charlie'), 	"1.2 match");
ok(1 == $grammar->('hey alice'), 	"1.3 match");
ok(1 == $grammar->('howdy bob'), 	"1.4 match");
ok(1 == $grammar->('hi eve'), 		"1.5 match");
ok(1 == $grammar->('howdy dave'), 	"1.6 match");

ok(0 == $grammar->('hello david'), 	"2.1 no match");
ok(0 == $grammar->('hi, charlie'), 	"2.2 no match");
ok(0 == $grammar->('hey hey'), 		"2.3 no match");
ok(0 == $grammar->('howdy'), 		"2.4 no match");
ok(0 == $grammar->('eve'), 		"2.5 no match");
ok(0 == $grammar->('howdy howdy'), 	"2.6 no match");




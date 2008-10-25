
use Test::More tests=>20;

use Gnaw;

my $grammar;


sub greeting {alternation( lit('hello'), lit('howdy'), lit('hi'), lit('hey') )}

sub name { alternation( lit('alice'), lit('bob'), lit('charlie'), lit('dave'), lit('eve') ) }

sub greet_someone { series( greeting, name ) }


sub quest { alternation ( lit('who'), lit('what'), lit('where'), lit('when') ) }

sub question_someone { series( quest, lit('are'), lit('you'), lit('?') ) }



sub general_pleasantry { alternation (
	greet_someone,
	question_someone
);}


$grammar = match(general_pleasantry);


ok(1 == $grammar->('hello dave'), 	"1.1 match");
ok(1 == $grammar->('hi charlie'), 	"1.2 match");
ok(1 == $grammar->('hey alice'), 	"1.3 match");
ok(1 == $grammar->('howdy bob'), 	"1.4 match");
ok(1 == $grammar->('hi eve'), 		"1.5 match");
ok(1 == $grammar->('howdy dave'), 	"1.6 match");


ok(1 == $grammar->('who are you?'), 	"1.7 match");
ok(1 == $grammar->('what are you?'), 	"1.8 match");
ok(1 == $grammar->('where are you?'), 	"1.9 match");
ok(1 == $grammar->('when are you?'), 	"1.10 match");


ok(0 == $grammar->('hello david'), 	"2.1 no match");
ok(0 == $grammar->('hi, charlie'), 	"2.2 no match");
ok(0 == $grammar->('hey hey'), 		"2.3 no match");
ok(0 == $grammar->('howdy'), 		"2.4 no match");
ok(0 == $grammar->('eve'), 		"2.5 no match");
ok(0 == $grammar->('howdy howdy'), 	"2.6 no match");

ok(0 == $grammar->('whom are you?'), 	"2.7 no match");
ok(0 == $grammar->('what were you?'), 	"2.8 no match");
ok(0 == $grammar->('where are we?'), 	"2.9 no match");
ok(0 == $grammar->('when are you.'), 	"2.10 no match");




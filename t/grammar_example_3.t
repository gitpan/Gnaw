
use Test::More tests=>44;

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


sub trek_captain_name { alternation( lit('Jim'), series( lit('Captain'), lit('Kirk') ), lit('Captain'), lit('Kirk') ) }
sub trek_doctor_name { alternation( lit('Bones'), series( lit('Doctor'), lit('McCoy') ), lit('Doctor'), lit('McCoy') ) }
sub trek_spock_name {alternation( 
	lit('Spock'), 
	series(lit('Mr.'), lit('Spock')), 
	series(lit('you'), lit('green-blooded'), lit('Vulcan'))
)}

sub trek_name { alternation (
	trek_captain_name,
	trek_doctor_name,
	trek_spock_name
)}


sub spock_statement { alternation (
	series( lit('fascinating'), lit(','), trek_name, lit('.') ),
	series( lit('highly'), lit('illogical'), lit(','), trek_name, lit('.') )
) }

sub cursing {
	alternation( lit('dammit'), series(lit('damn'), lit('it')) )
}

sub profession { alternation( 
	series(lit('ditch'), lit('digger')), 
	series(lit('brick'), lit('layer')) ,
	lit('carpenter')
)}

sub bones_statement { alternation (
	series( cursing, trek_name, lit(','), lit('Im'), lit('a'), lit('doctor'), lit(','),  lit('not'), lit('a'), profession, lit('!') ),
	series( alternation(lit('he'), lit('she')), lit('is'), lit('dead'), lit(','), trek_name, lit('.'))
)}


sub conversation { alternation (
	general_pleasantry,
	spock_statement,
	bones_statement
) }


$grammar = match(conversation);
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

ok(1 == $grammar->('fascinating, Kirk.'), 		"1.11 match");
ok(1 == $grammar->('fascinating, Captain Kirk.'), 	"1.12 match");
ok(1 == $grammar->('fascinating, Captain.'), 		"1.13 match");
ok(1 == $grammar->('fascinating, Jim.'), 		"1.14 match");

ok(1 == $grammar->('highly illogical, Jim.'), 		"1.15 match");
ok(1 == $grammar->('highly illogical, Doctor.'), 	"1.16 match");
ok(1 == $grammar->('highly illogical, Doctor McCoy.'), 	"1.17 match");
ok(1 == $grammar->('highly illogical, McCoy.'), 	"1.18 match");
ok(1 == $grammar->('highly illogical, Bones.'), 	"1.19 match");

ok(1 == $grammar->("dammit Jim, Im a doctor, not a ditch digger!"), 			"1.20 match");
ok(1 == $grammar->("dammit Spock, Im a doctor, not a brick layer!"), 			"1.21 match");
ok(1 == $grammar->("dammit you green-blooded Vulcan, Im a doctor, not a carpenter!"), 	"1.22 match");



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

ok(0 == $grammar->('fascinating Kirk.'), 		"2.11 no match");
ok(0 == $grammar->('fascinating, Captain Kirk'), 	"2.12 no match");
ok(0 == $grammar->('fascinating, Kirk Captain.'), 	"2.13 no match");
ok(0 == $grammar->('fascinating, Jimbo.'), 		"2.14 no match");

ok(0 == $grammar->('highly illogical, Jim'), 		"2.15 no match");
ok(0 == $grammar->('highly illogical Doctor.'), 	"2.16 no match");
ok(0 == $grammar->('highly illogical, Doctor Doctor.'), "2.17 no match");
ok(0 == $grammar->('highly illogical.'), 		"2.18 no match");
ok(0 == $grammar->('highly illogical, Bone head.'), 	"2.19 no match");

ok(0 == $grammar->("dammit Jim, Im a doctor, not a ditch layer!"), 			"2.20 no match");
ok(0 == $grammar->("dammit Spock, Im a doctor, not a brick digger!"), 			"2.21 no match");
ok(0 == $grammar->("dammit you green-blooded Vulcan, Im a doctor, not a pilot!"), 	"2.22 no match");



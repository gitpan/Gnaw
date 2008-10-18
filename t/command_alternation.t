

use Test::More tests=>4;

use Gnaw;

my $grammar = match(alternation(lit('alice'), lit('bob')));


ok( 1==$grammar->('hello alice'), "alternation(alice,bob) in 'hello alice'");
ok( 0==$grammar->('hello world'), "alternation(alice,bob) in 'hello world'");




sub greet_all { series(lit('hello'), lit('world'));}

# another alternative will be a series of two literals, "howdy" followed by "partner"
sub greet_one { series(lit('howdy'), lit('partner'));}

# look for either greeting
my $biggrammar = match(alternation(greet_all, greet_one));


ok( 1==$biggrammar->('hey hello world there'), "bigalternation in 'hey hello world there'");
ok( 0==$biggrammar->('hello howdy world partner'), "bigalternation in 'hello howdy world partner'");

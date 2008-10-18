

use Test::More tests=>15;

use Gnaw;

my $grammar;


$grammar = match(quantifier('t', lit('a'), 3,7));
ok( 1==$grammar->('abcdefaaaaahjklm'), "look for 3 to 7 letter 'a'. Use a thrifty search. given enough a's");
ok( 1==$grammar->('abcdefaaaaaaaaaaaaaaahjklm'), "look for 3 to 7 letter 'a'. Use a thrifty search. given lots of a's");
ok( 0==$grammar->('abcdefaahjklm'), "look for 3 to 7 letter 'a'. Use a thrifty search. given insufficient a's");

 
$grammar = match(quantifier('t', lit('a'), 3));
ok( 1==$grammar->('abcdefaaaaahjklm'), "look for 3 or more letter 'a'. still thrifty. given enough a's");
ok( 0==$grammar->('abcdefaahjklm'), "look for 3 or more letter 'a'. still thrifty. given insufficient a's");


$grammar = match(quantifier('g', lit('a'), 3));
ok( 1==$grammar->('abcdefaaaaahjklm'), "look for 3 or more letter 'a'. greedy search. given enough a's");
ok( 0==$grammar->('abcdefaahjklm'), "look for 3 or more letter 'a'. greedy search. given insufficient a's");


$grammar = match(quantifier(lit('a'), 3));
ok( 1==$grammar->('abcdefaaaaahjklm'), "look for 3 or more letter 'a'. assumed greedy search. given enough a's");
ok( 0==$grammar->('abcdefaahjklm'), "look for 3 or more letter 'a'. assumed greedy search. given insufficient a's");

$grammar = match(quantifier(lit('a'), 's'));
ok( 1==$grammar->('abcdefaaaaahjklm'), "look for a when quantity is specified as 's'. given enough a's");
ok( 0==$grammar->('xbcdeffghhjklm'), "look for a when quantity is specified as 's'. given insufficient a's");

$grammar = match(quantifier(lit('a'), '+'));
ok( 1==$grammar->('abcdefaaaaahjklm'), "look for a when quantity is specified as '+'. given enough a's");
ok( 0==$grammar->('xbcdeffghhjklm'), "look for a when quantity is specified as '+'. given insufficient a's");

$grammar = match(quantifier(lit('a'), '*'));
ok( 1==$grammar->('abcdefaaaaahjklm'), "look for a when quantity is specified as '*'. given some a's ");
ok( 1==$grammar->('xbcdeffghhjklm'), "look for a when quantity is specified as '+'. given no a's ");

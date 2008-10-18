

use Test::More tests=>6;

use Gnaw;

my $grammar;

my $counter;

sub mycallback { callback(sub{$counter++;}) }

$grammar = match(  greedy( series(lit('a'), mycallback), 7,9) );
$counter=0;
ok( 0==$grammar->('aaaaa'), "greedy nocommit, confirm no match");
ok( $counter==0, "greedy nocommit, confirm counter is zero");

$grammar = match(  greedy( series(lit('a'), mycallback, commit), 7,9) );
$counter=0;
ok( 0==$grammar->('aaaaa'), "greedy commit, confirm no match");
ok( $counter==5, "greedy commit, confirm counter is incremented once for each 'a'");



$grammar = match(  series(lit('a'), mycallback, lit('a'), commit, lit('a'), lit('a'))  );

$counter=0;
ok( 0==$grammar->('aaa'), "series commit, confirm no match");
ok( $counter==1, "series commit, confirm counter is one");

print STDERR "counter is '$counter'\n";

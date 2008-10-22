

use Test::More tests=>4;

use Gnaw;

my $grammar;

my $counter;

sub mycallback { callback(sub{$counter++;}) }

# this is the most basic grammar that uses commit.
# note that commit doesn't work with quantifiers yet.
# haven't figured it out yet.

$grammar = match( lit('a'), lit('a'), lit('a'), mycallback, lit('a'), lit('a'), lit('a'), );
$counter=0;
ok( 0==$grammar->('aaaaa'), "greedy nocommit, confirm no match");
ok( $counter==0, "greedy nocommit, confirm counter is zero");

$grammar = match( lit('a'), lit('a'), lit('a'), mycallback, lit('a'), commit, lit('a'), lit('a'), );
$counter=0;
ok( 0==$grammar->('aaaaa'), "greedy commit, confirm no match");
ok( $counter==1, "greedy commit, confirm counter is incremented once for each 'a'");




use Test::More tests=>6;

use Gnaw;

my $grammar;

my $counter;
$grammar = match(quantifier('t', series(lit('a'), sub{$counter++;}) , 7,9));


$counter = 0;
ok( 0==$grammar->('xxxaaaaayyy'), "direct subroutine confirm no match");

# dont care exactly how many times counter is incremented. just want to make sure that
# its more than the callback number of times. Callback mode called 7 times. so want
# the non-callback count to be > 7
ok( $counter>7, "direct subroutine confirm counter incremented for each attempt of an 'a'");

$counter = 0;

$grammar = match(quantifier('t', series(lit('a'),   callback(sub{$counter++;})    ) , 7,9));

ok( 0==$grammar->('xxxaaaaayyy'), "callback, confirm no match");
ok( $counter==0, "callback, confirm callback not called");



$counter = 0;
ok( 1==$grammar->('xxxaaaaaaaaaaaayyy'), "callback, confirm match");
ok( $counter==7, "callback, confirm callback called");

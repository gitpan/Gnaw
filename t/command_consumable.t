

use Test::More tests=>3;

use Gnaw;


my $captured;

my $callback = sub {
	$captured = shift(@_);
};


sub fruit {alternation(lit('apple'), lit('pear'), lit('peach'), lit('orange'))}

sub eatfruit {  consumable(capture( fruit , $callback)) }

# this doesn't work yet. quantifiers and consumables clash.
# $grammar = match( greedy(fruit, 's'));


$grammar = match( eatfruit );

ok( 1==$grammar->('peach apple pear orange'), "1.1");
ok( $captured eq 'peach', "1.2, checking capture");
my $final = __gnaw__get_entire_string();

ok( $final eq ' apple pear orange', "1.3, checking what's left, confirming consumed");


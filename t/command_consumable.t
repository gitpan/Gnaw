

use Test::More tests=>6;

use Gnaw;

my $captured=[];

my $callback = sub {
	my $text = shift(@_);
	push(@$captured, $text);
};


sub fruit {alternation(lit('apple'), lit('pear'), lit('peach'), lit('orange'))}
sub eatfruit {  consumable(capture( fruit , $callback)) }
$grammar = match( greedy(eatfruit, 's'));

ok( 1==$grammar->('peach apple pear orange potato'), "1.1 confirm match");

ok( ($captured->[0]) eq 'peach', "2.2, checking capture");
ok( ($captured->[1]) eq 'apple', "2.3, checking capture");
ok( ($captured->[2]) eq 'pear', "2.4, checking capture");
ok( ($captured->[3]) eq 'orange', "2.5, checking capture");

my $final = __gnaw__get_entire_string();

ok( $final eq ' potato', "3.3, checking what's left, confirming consumed");


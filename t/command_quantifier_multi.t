

use Test::More tests=>15;

use Gnaw;

my $grammar;

my $first_capture;
my $first_callback = sub {$first_capture=shift(@_);};

my $second_capture;
my $second_callback = sub {$second_capture=shift(@_);};



$grammar = 
	match(
		series( 
			capture(greedy(lit('x'),'s'),$first_callback), 
			capture(greedy(lit('x'),'s'),$second_callback)
		)
	);


ok( $grammar->('xxxxx') , "1.1 confirm match");

ok( $first_capture eq 'xxxx', "1.2 confirm first capture");
ok( $second_capture eq 'x', "1.3 confirm second capture");



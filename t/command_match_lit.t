

use Test::More tests=>4;

use Gnaw;

my $grammar = match(lit('hello'));


ok( 1==$grammar->('hello world'), "'hello' in 'hello world'");
ok( 0==$grammar->('goodbye world'), "'hello' in 'goodbye world'");
ok( 1==$grammar->('why hello there'), "'hello' in 'why hello there'");
ok( 1==$grammar->('why hello'), "'hello' in 'why hello'");




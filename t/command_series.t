

use Test::More tests=>4;

use Gnaw;

my $grammar = match( series(lit('hello'), lit('world')) );


ok( 1==$grammar->('hello world'), "series 'hello'+'world' in 'hello world'");
ok( 0==$grammar->('goodbye world'), "series 'hello'+'world' in 'goodbye world'");
ok( 0==$grammar->('hello there world'), "series 'hello'+'world' in 'hello there world'");
ok( 1==$grammar->('why hello world, how are you?'), "series 'hello'+'world' in 'why hello world, how are you?'");




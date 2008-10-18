

use Test::More tests=>2;

use Gnaw;

my $grammar = match(set("xyz"));


ok( 0==$grammar->('hello world'), "set('xyz') in 'hello world'");
ok( 1==$grammar->('hello Dolly'), "set('xyz') in 'hello Dolly'");





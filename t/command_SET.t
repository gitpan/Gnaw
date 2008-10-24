

use Test::More tests=>2;

use Gnaw;

my $grammar = match(SET("xyz"));


ok( 1==$grammar->('hello world'), "SET('xyz') in 'hello world'");
ok( 0==$grammar->('zzzzxxxxxyyyy'), "SET('xyz') in 'zzzzxxxxxyyyy'");





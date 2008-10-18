

use Test::More tests=>2;

use Gnaw;

my $grammar = match(set_n("xyz"));


ok( 1==$grammar->('hello world'), "set_n('xyz') in 'hello world'");
ok( 0==$grammar->('zzzzxxxxxyyyy'), "set_n('xyz') in 'zzzzxxxxxyyyy'");





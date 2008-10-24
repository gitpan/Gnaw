

use Test::More tests=>10;

use Gnaw;

my $grammar = match(lit('b'), thing, lit('b'));


ok( 1==$grammar->('bob'), "1.1 bob matches b thing b");
ok( 1==$grammar->('bib'), "1.2 bib matches b thing b");
ok( 1==$grammar->('b_b'), "1.3 b_b matches b thing b");
ok( 1==$grammar->('b9b'), "1.4 b9b matches b thing b");


ok( 0==$grammar->('bb'), "1.5 bb does not match b thing b");
ok( 0==$grammar->('bc'), "1.6 bc does not match b thing b");
ok( 0==$grammar->('cb'), "1.7 cb does not match b thing b");

ok( 0==$grammar->('aaabbaaa'), "1.8  aaabbaaa does not match b thing b");
ok( 0==$grammar->('aaabcaaa'), "1.9  aaabcaaa does not match b thing b");
ok( 0==$grammar->('aaacbaaa'), "1.10 aaacbaaa does not match b thing b");







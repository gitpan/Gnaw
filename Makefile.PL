use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Gnaw',
    AUTHOR              => 'Greg London <email@greglondon.com>',
    VERSION_FROM        => 'lib/Gnaw.pm',
    ABSTRACT_FROM       => 'lib/Gnaw.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Gnaw-*' },

    ($ExtUtils::MakeMaker::VERSION >= 6.3002 ?
          ('LICENSE'		=> 'perl', ) : ()),
);

use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'RestAPI',
    AUTHOR           => q{Marco Masetti <marco.masetti@sky.uk>},
    VERSION_FROM     => 'lib/RestAPI.pm',
    ABSTRACT_FROM    => 'lib/RestAPI.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    EXE_FILES        => [ qw(scripts/rest-client.pl) ],
    MIN_PERL_VERSION => '5.006',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
        'Test::More' => '0',
    },
    PREREQ_PM => {
        'Encode'            => 0,
        'Getopt::Long'      => 0,
        'JSON::XS'          => 0,
        'Log::Log4perl'     => 0,
        'LWP::UserAgent'    => 0,
        'LWP::ConsoleLogger::Everywhere' => 0,
        'Moose'             => 0,
        'XML::Simple'       => 0,
        'Time::HiRes'       => 0,
        'namespace::autoclean' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'RestAPI-*' },
);

use strict;
use warnings;
use RestAPI;
use Test::More;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($DEBUG);

ok(my $c = RestAPI->new(
        query       => 'http://www.thomas-bayer.com/sqlrest',
        path        => 'CUSTOMER',
        encoding    => 'application/xml',
    ), 'new' );

ok( my $customers = $c->do(), 'do' );
is( ref $customers, 'HASH', 'got right data type back');

done_testing;




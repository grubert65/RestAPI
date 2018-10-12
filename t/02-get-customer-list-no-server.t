use strict;
use warnings;
use RestAPI;
use Test::More;

ok(my $c = RestAPI->new(
        query       => 'http://www.thomas-bayer.com/sqlrest',
        path        => 'CUSTOMER',
        encoding    => 'application/xml',
    ), 'new' );

ok( my $customers = $c->do(), 'do' );
is( ref $customers, 'HASH', 'got right data type back');

done_testing;




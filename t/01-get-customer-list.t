use strict;
use warnings;
use RestAPI;
use Test::More;

ok(my $c = RestAPI->new(
        scheme      => 'http',
        server      => 'www.thomas-bayer.com',
        port        => 80,
        query       => 'sqlrest',
        q_params    => { 
            k1  => 'v1',
        },
        path        => 'CUSTOMER',
        http_verb   => 'GET',
        encoding    => 'application/xml',
    ), 'new' );

ok( my $customers = $c->do(), 'do' );
is( ref $customers, 'HASH', 'got right data type back');

done_testing;




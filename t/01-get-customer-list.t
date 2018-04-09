use strict;
use warnings;
use RestAPI;
use Test::More;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($DEBUG);

ok(my $c = RestAPI->new(
        scheme      => 'http',
        server      => 'www.thomas-bayer.com',
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




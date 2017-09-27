package RestAPI;
#===============================================================================

=head1 NAME

RestAPI - a base module to interact with a REST API interface

=head1 VERSION

Version 0.02

=cut

our $VERSION = "0.02";

=head1 SYNOPSIS

    use RestAPI;

    # a REST GET request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        realm       => "Some Realm",
        ssl_opts    => { verify_hostname => 0 },
        username    => "foo",
        password    => "bar",
        scheme      => 'https', # if missing it is assumed comprised in the server
        server      => '...',
        query       => '...',   # (maybe fixed) request part
        path        => '...',   # added alongside the request
        q_params    => '?foo=bar',
        http_verb   => 'GET',            # any http verb...
        encoding    => 'application/xml' # or whatever...
    );

    # a REST POST request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        realm       => "Some Realm",
        username    => "foo",
        password    => "bar",
        scheme      => 'https',
        server      => '...',
        query       => '...',
        path        => '...',
        q_params    => '?foo=bar',
        http_verb   => 'POST',
        payload     => '...',
        encoding    => 'application/xml'
    );

    # a REST UPDATE request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        realm       => "Some Realm",
        username    => "foo",
        password    => "bar",
        scheme      => 'https',
        server      => '...',
        query       => '...',
        path        => '...',
        q_params    => '?foo=bar',
        http_verb   => 'PUT',
        payload     => '...',
        encoding    => 'application/xml'
    );

    # a REST DELETE request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        realm       => "Some Realm",
        username    => "foo",
        password    => "bar",
        scheme      => 'https',
        server      => '...',
        query       => '...',
        path        => '...',
        q_params    => '?foo=bar',
        http_verb   => 'DELETE',
        encoding    => 'application/xml'
    );

    my $response_object = $dumper->do();
    my $raw_response = $dumper->raw();  # the raw response.

=head1 EXPORT

None

=head1 AUTHOR

Marco Masetti, C<< <marco.masetti at sky.uk> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RestAPI


=head1 LICENSE AND COPYRIGHT

Copyright 2017 Marco Masetti.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=head1 SUBROUTINES/METHODS

=cut

#===============================================================================
use Moose;
use namespace::autoclean;
use XML::Simple             qw( XMLin );
use JSON;
use Log::Log4perl ();
use LWP::UserAgent ();
use Encode                  qw( encode );


# Basic construction params
has 'ssl_opts'  => ( is => 'rw', isa => 'HashRef' );
has 'basicAuth' => ( is => 'rw', isa => 'Bool');
has 'realm'     => ( is => 'rw', isa => 'Str' );
has 'username'  => ( is => 'rw', isa => 'Str' );
has 'password'  => ( is => 'rw', isa => 'Str' );
has 'scheme'    => ( is => 'rw', isa => 'Str' );
has 'server'    => ( is => 'rw', isa => 'Str' );

# Added construction params
has 'query'     => ( is => 'rw', isa => 'Str' );
has 'path'      => ( is => 'rw', isa => 'Str' );
has 'q_params'  => ( is => 'rw', isa => 'Str' );
has 'http_verb' => ( is => 'rw', isa => 'Str' );
has 'payload'   => ( is => 'rw', isa => 'Str' );
has 'encoding'  => ( is => 'rw', isa => 'Str' );

# internal objects
has 'req'       => ( is => 'ro', isa => 'HTTP::Request', writer => '_set_req' );
has 'ua'        => ( is => 'ro', isa => 'LWP::UserAgent', writer => '_set_ua' );
has 'jsonObj'   => ( is => 'ro', isa => 'JSON', default => sub{ JSON->new->allow_nonref } );
has 'raw'       => ( is => 'ro', isa => 'Str', writer => '_set_raw' );
has 'log'       => ( 
    is => 'ro', 
    isa => 'Log::Log4perl::Logger',
    default => sub {
        return Log::Log4perl->get_logger( __PACKAGE__ );
    }
);

sub BUILD {
    my $self = shift;
    $self->_set_ua( LWP::UserAgent->new(
        ssl_opts => $self->ssl_opts,
    ));

    if ( $self->basicAuth ) {
        $self->ua->credentials( $self->server, $self->realm, $self->username, $self->password );
    }

    if ( $self->scheme ) {
        $self->server($self->scheme . '://' . $self->server);
    } 

    my $url = $self->server;

    if ( $self->query ) {
        $self->{query} = '/'.$self->{query} unless ( $self->{query} =~ m|^/| );
        $url .= $self->query;
    }

    if ( $self->path ) {
        $self->{path} = '/'.$self->{path} unless ( $self->{path} =~ m|^/| );
        $url .= $self->path;
    }

    $url .= $self->q_params if ( $self->q_params );

    my $h = HTTP::Headers->new;
    $h->header('Content-Type' => $self->encoding) if ( $self->encoding );

    my $payload;
    $payload = encode('UTF-8', $self->payload, Encode::FB_CROAK) if ( $self->payload );
    $self->_set_req( HTTP::Request->new( $self->http_verb, $url, $h, $payload ) )
}

#===============================================================================

=head2 do

=head3 INPUT

none

=head3 OUTPUT

It actually executes the REST request.
It returns the decoded object or the plain response back.

=cut

#===============================================================================
sub do {
    my $self = shift;

    my $outObj;
    my $resp = $self->ua->request( $self->req );
    if ( $resp->is_success ) {
        $self->_set_raw( $resp->decoded_content );
        $self->log->debug("Raw Response:");
        $self->log->debug($self->raw);
         
        # if response string is html, we print as it is...
        if ( $self->raw =~ /^<html/i ) {
            return $self->raw;
        }

        if ( $self->encoding eq 'application/xml' ) {
            if ( $self->raw =~ /^<\?xml/ ) {
                $outObj = XMLin( $self->raw );
            } else {
                return $self->raw;
            }
        } elsif ( $self->encoding eq 'application/json' ) {
            $outObj = $self->jsonObj->decode( $self->raw );
        } else {
            print "Encoding $self->{encoding} not supported...\n";
            return $self->raw;
        }
    } else {
        die "Error: ".$resp->status_line;
    }
    return $outObj;
}
1; 
 


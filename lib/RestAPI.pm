package RestAPI;
#===============================================================================

=head1 NAME

RestAPI - a base module to interact with a REST API interface

=head1 VERSION

Version 0.07

=cut

our $VERSION = "0.07";

=head1 SYNOPSIS

    use RestAPI;

    # a REST GET request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        realm       => "Some Realm",
        ssl_opts    => { verify_hostname => 0 },
        username    => "foo",
        password    => "bar",
        scheme      => 'https', # if missing it is assumed comprised in the server or in the query
        server      => '...',
        query       => '...',   # (maybe fixed) request part
        path        => '...',   # added alongside the request
        q_params    => { foo => bar },
        headers     => { k => 'v' },
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
        q_params    => { foo => bar },
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
        q_params    => { foo => bar },
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
        q_params    => { foo => bar },
        http_verb   => 'DELETE',
        encoding    => 'application/xml'
    );

    try {
        my ($response_object, $response_headers) = $dumper->do();
    } catch {
        die "Error performing request, status line: $!\n";
    }

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
use Data::Printer;


# Basic construction params
has 'ssl_opts'  => ( is => 'rw', isa => 'HashRef' );
has 'basicAuth' => ( is => 'rw', isa => 'Bool');
has 'realm'     => ( is => 'rw', isa => 'Str' );
has 'username'  => ( is => 'rw', isa => 'Str' );
has 'password'  => ( is => 'rw', isa => 'Str' );
has 'scheme'    => ( is => 'rw', isa => 'Str' );
has 'server'    => ( is => 'rw', isa => 'Str' );
has 'timeout'   => ( is => 'rw', isa => 'Int', default => 10 );

# Added construction params
has 'headers'   => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'query'     => ( is => 'rw', isa => 'Str' );
has 'path'      => ( is => 'rw', isa => 'Str', trigger => \&_set_request );
has 'q_params'  => ( is => 'rw', isa => 'HashRef', default => sub {{}}, trigger => \&_set_q_params );
has 'http_verb' => ( is => 'rw', isa => 'Str', default => 'GET' );
has 'payload'   => ( is => 'rw', isa => 'Str' );
has 'encoding'  => ( is => 'rw', isa => 'Str' );

# internal objects
has 'req'       => ( is => 'ro', isa => 'HTTP::Request', writer => '_set_req' );
has 'req_params' => ( is => 'ro', isa => 'Str', default => sub { '' }, writer => '_set_req_params');
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
        timeout  => $self->timeout,
    ));

    if ( $self->basicAuth ) {
        $self->ua->credentials( $self->server, $self->realm, $self->username, $self->password );
    }

    if ( $self->scheme ) {
        $self->server($self->scheme . '://' . $self->server);
    } 

    $self->_set_request();
}

sub _set_q_params {
    my $self = shift;
    my $q_params;
    if ( scalar keys %{$self->q_params} ) {
        $q_params = '?';
        my $params = $self->q_params;
        my $k = (keys %$params)[0]; # we take out the first...
        my $v = delete $params->{$k};
        $q_params .= "$k=$v";
        while ( ( $k, $v ) = each %$params ) {
            $q_params .= '&'."$k=$v";
        }
    }
    $self->_set_req_params( $q_params );
}

sub _set_request {
    my $self = shift;

    my $url;
    $url = $self->server if ( $self->server );

    if ( $self->query ) {
        $self->{query} = '/'.$self->{query} if ( $url && $self->{query} !~ m|^/|);
        $url .= $self->query;
    }

    if ( $self->path ) {
        $self->{path} = '/'.$self->{path} unless ( $self->{path} =~ m|^/| );
        $url .= $self->path;
    }

    $url .= $self->req_params;

    my $h = HTTP::Headers->new;
    $h->content_type($self->encoding) if ( $self->encoding );

    while ( my ( $k, $v ) = each( %{$self->headers} ) ) {
        $h->header( $k, $v );
    }

    my $payload;
    $payload = encode('UTF-8', $self->payload, Encode::FB_CROAK) if ( $self->payload );

    $self->log->debug("-" x 80);
    $self->log->debug("Request:");
    $self->log->debug("Headers: ", join(", ", $h->flatten));
    $self->log->debug("[$self->{http_verb}]: $url");
    $self->log->debug("Payload:\n", $payload) if ( $payload );
    $self->log->debug("-" x 80);

    $self->_set_req( HTTP::Request->new( $self->http_verb, $url, $h, $payload ) );
}

#===============================================================================

=head2 do

=head3 INPUT

none

=head3 OUTPUT

An array.

It actually executes the REST request.
It returns an array with these items:
- the decoded object or the plain response back.
- the hashref of response headers

Or dies in case of errors.

=cut

#===============================================================================
sub do {
    my $self = shift;

    my $outObj;
    my %headers;
    my $resp = $self->ua->request( $self->req );
    if ( $resp->is_success ) {
        %headers = $resp->flatten();
        $self->_set_raw( $resp->decoded_content );
        my $r_encoding = $resp->header("Content_Type");
        $self->log->debug("-" x 80);
        $self->log->debug("Response Content-Type:", $r_encoding);
        $self->log->debug("Response Headers:");
        $self->log->debug( np( %headers ) );
        if ( exists $headers{'Content-Transfer-Encoding'} &&
            $headers{'Content-Transfer-Encoding'} eq 'binary' ) {
            return ($self->raw, \%headers);
        }
        $self->log->debug("Raw Response:");
        $self->log->debug($self->raw);
        $self->log->debug("-" x 80);
         
        # if response string is html, we print as it is...
        if ( $self->raw =~ /^<html/i ) {
            return ($self->raw, \%headers);
        }

        if ( $r_encoding =~ m|application/xml| ) {
            if ( $self->raw =~ /^<\?xml/ ) {
                $outObj = XMLin( $self->raw );
            } else {
                return ($self->raw, \%headers);
            }
        } elsif ( $r_encoding =~ m|application/json| ) {
            $outObj = $self->jsonObj->decode( $self->raw );
        } elsif ( $r_encoding =~ m|text/plain| ) {
            $outObj = $self->raw;
        } else {
            print "Encoding $r_encoding not supported...\n";
            return ($self->raw, \%headers);
        }
    } else {
        die "Error: ".$resp->status_line;
    }
    return ($outObj, \%headers);
}
1; 
 


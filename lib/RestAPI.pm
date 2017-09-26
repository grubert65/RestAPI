package RestAPI;
#===============================================================================

=head1 NAME

RestAPI - a base module to interact with a REST API interface

=head1 VERSION

Version 0.01

=cut

our $VERSION = "0.01";

=head1 SYNOPSIS

    use RestAPI;

    # a REST GET request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        username    => "foo",
        password    => "bar",
        scheme      => 'https', # if missing it is assumed comprised in the server...
        server      => '...',
        request     => '...',   # (maybe fixed) request part
        path        => '...',   # added alongside the request
        q_params    => '?foo=bar',
        http_verb   => 'GET',            # any http verb...
        encoding    => 'application/xml' # or whatever...
    );

    # a REST POST request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        username    => "foo",
        password    => "bar",
        scheme      => 'https',
        server      => '...',
        request     => '...',
        path        => '...',
        q_params    => '?foo=bar',
        http_verb   => 'POST',
        payload     => '...',
        encoding    => 'application/xml'
    );

    # a REST UPDATE request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        username    => "foo",
        password    => "bar",
        scheme      => 'https',
        server      => '...',
        request     => '...',
        path        => '...',
        q_params    => '?foo=bar',
        http_verb   => 'PUT',
        payload     => '...',
        encoding    => 'application/xml'
    );

    # a REST DELETE request
    my $dumper = RestAPI->new(
        basicAuth   => 1,
        username    => "foo",
        password    => "bar",
        scheme      => 'https',
        server      => '...',
        request     => '...',
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


has 'jsonObj'   => ( is => 'rw', isa => 'JSON', default => sub{ JSON->new->allow_nonref } );
has 'basicAuth' => ( is => 'rw', isa => 'Bool');
has 'username'  => ( is => 'rw', isa => 'Str' );
has 'password'  => ( is => 'rw', isa => 'Str' );
has 'scheme'    => ( is => 'rw', isa => 'Str' );
has 'server'    => ( is => 'rw', isa => 'Str' );
has 'request'   => ( is => 'rw', isa => 'Str' );
has 'path'      => ( is => 'rw', isa => 'Str' );
has 'q_params'  => ( is => 'rw', isa => 'Str' );
has 'http_verb' => ( is => 'rw', isa => 'Str' );
has 'payload'   => ( is => 'rw', isa => 'Str' );
has 'encoding'  => ( is => 'rw', isa => 'Str' );
has 'debug'     => ( is => 'rw', isa => 'Bool');
has 'raw'       => ( is => 'rw', isa => 'Str' );
has 'log'       => ( 
    is => 'ro', 
    isa => 'Log::Log4perl::Logger',
    default => sub {
        return Log::Log4perl->get_logger( __PACKAGE__ );
    }
);

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

    my $cmd = 'curl -k1 ';
    $cmd .= "-H \"Content-type: $self->{encoding}\" " if ( $self->encoding );
    $cmd .= "-u $self->{username}:$self->{password}"  if ( $self->basicAuth );
    $cmd .= " -X $self->{http_verb} ";
    $self->{request} = '/'.$self->{request}           unless ( $self->{request} =~ m|^/| );
    if ( $self->scheme ) {
        $cmd .= $self->scheme . '://' . $self->server;
    } else {
        $cmd .= $self->server;
    }
    $cmd .= $self->request                            if ( $self->request );
    $cmd .= "/$self->{path}"                          if ( $self->path );
    $cmd .= $self->{q_params}                         if ( $self->q_params );
    $cmd .= " -d '$self->{payload}'"                  if ( $self->payload );

    $self->log->debug("REQUEST:\n$cmd\n");

    $self->{raw} = `$cmd`;

    $self->log->debug("Raw Response:");
    $self->log->debug($self->raw);
    my $outObj;

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

    return $outObj;
}
1; 
 


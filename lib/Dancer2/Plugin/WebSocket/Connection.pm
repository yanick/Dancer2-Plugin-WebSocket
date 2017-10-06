package Dancer2::Plugin::WebSocket::Connection;
# ABSTRACT: Role tying Plack::App::WebSocket::Connection with the Dancer serializer

=head1 DESCRIPTION

The connection objects used by L<Dancer2::Plugin::WebSocket> are
L<Plack::App::WebSocket::Connection> objects augmented with this role.

This role does two itsy bitsy things: it adds a read-write C<serializer> attribute,
which typically will be populated by the plugin, and adds an C<around>
modifier for the C<send> method that, if a serializer is configured, 
will serialize any outgoing message that is not a L<AnyEvent::WebSocket::Message>
object.

=cut

use Moo::Role;

has serializer => (
    is => 'rw',
);

around send => sub {
    my( $orig, $self, $message ) = @_;
    if( my $s = $self->serializer and ref $message ne 'AnyEvent::WebSocket::Message' ) {
        $message = $s->encode($message);
    }
    $orig->($self,$message);
};

1;

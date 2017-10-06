package Dancer2::Plugin::WebSocket::Connection;

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

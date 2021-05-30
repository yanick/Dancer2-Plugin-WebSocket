package Dancer2::Plugin::WebSocket::Group;
# ABSTACT: Grouping of connections to send messages to

=head1 SYNOPSIS

    websocket_on_message sub {
        my( $conn, $message ) = @_;

        if ( $message eq 'tell to everybody' ) {
            $conn->to( '* ' )->send( "HEY, Y'ALL!" );
        }
    };

=head1 DESC

Those objects are generated via the C<to> method of the L<Dancer2::Plugin::WebSocket::Connection>
objects, and allow to easily send to groups of connections.

In addition to any channels one might fancy creating, each connection also has a private
channel that is associated to its numerical id, and a global channel C<*> also exist
to send messages to all connections.

=cut

use strict;
use warnings;

use Moo;

=head2 Methods

=cut

has source => (
    is => 'ro',
    required => 1,
);

has channels => (
    is => 'ro',
    required => 1,
);

use Set::Tiny;

sub targets {
    my ( $self, $omit_self ) = @_;

    my $channels = Set::Tiny->new( @{$self->channels} );

    return grep {
        $_->in_channel($channels) and
        ( !$omit_self or $self->source->id != $_->id )
    } values %{ $self->source->manager->connections };
}

=over

=item send( $message )

Send the message to all connections of the group.

    $conn->to( 'players' )->send( "Hi!" );

=cut

sub send {
    my ( $self, @args ) = @_;

    $_->send(@args) for $self->targets;
}

=item broadcast( $message )

Send the message to all connections of the group, except the original connection.

    websocket_on_message sub {
        my( $conn, $msg ) = @_;

        if ( $msg eq ='resign' ) {
            $conn->broadcast( "player ", $conn->idm " resigned" );
        }
    }

=back

=cut

sub broadcast {
    my ( $self, @args ) = @_;

    $_->send(@args) for $self->targets(1);
}


1;

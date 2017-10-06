package Dancer2::Plugin::WebSocket;
# ABSTRACT: add a websocket interface to your Dancer app

=head1 SYNOPSIS

F<bin/app.psgi>:

    #!/usr/bin/env perl

    use strict;
    use warnings;

    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use Plack::Builder;

    use MyApp;

    builder {
        mount( MyApp->websocket_mount );
        mount '/' => MyApp->to_app;
    }

F<config.yml>:

    plugins:
        WebSocket:
            # default values
            serializer: 0
            mount_path: /ws

F<MyApp.pm>:

  package MyApp;

  use Dancer2;
  use Dancer2::Plugin::WebSocket;

  websocket_on_message sub {
    my( $conn, $message ) = @_;
    $message->{hello} = 'browser!';
    $conn->send( $message );
  };

  get '/' => sub {
    my $ws_url = websocket_url;
    return <<"END";
      <html>
        <head><script>
            var urlMySocket = "$ws_url";

            var mySocket = new WebSocket(urlMySocket);

            mySocket.onmessage = function (evt) {
              console.log( "Got message " + evt.data );
            };

            mySocket.onopen = function(evt) {
              console.log("opening");
              setTimeout( function() {
                mySocket.send('{"hello": "Dancer"}'); }, 2000 );
            };

      </script></head>
      <body><h1>WebSocket client</h1></body>
    </html>
  END
  };

  true;


=head1 DESCRIPTION

C<Dancer2::Plugin::WebSocket> provides an interface to L<Plack::App::WebSocket>
and allows to interact with the webSocket connections within the Dancer app.

L<Plack::App::WebSocket>, and thus this plugin, requires a plack server that
supports the psgi attributes 'streaming', 'nonblocking' and 'io'. L<Twiggy> 
is the most popular server that fits the bill.

=head1 CONFIGURATION

=over

=item serializer

If serializer is set to C<true>, messages will be assumed to be JSON objects and
will be automatically encoded/decoded using a L<JSON::MaybeXS> serializer.
If the value of C<serialier> is a hash, it'll be passed as arguments to the 
L<JSON::MaybeXS> constructor.

    plugins:
        WebSocket:
            serializer: 
                utf8:         1
                allow_nonref: 1

=item mount_path

Path for the websocket mountpoint. Defaults to C</ws>.


=back



=cut

use Plack::App::WebSocket;

use Dancer2::Plugin;

use Role::Tiny qw();

has serializer => (
    is => 'ro',
    from_config => 1,
    coerce => sub {
        my $serializer = shift or return undef;
        require JSON::MaybeXS;
        JSON::MaybeXS->new( ref $serializer ? %$serializer : () );
    },
);

has mount_path => (
    is => 'ro',
    from_config => sub { '/ws' },
);

=head1 PLUGIN KEYWORDS

In the various callbacks, the connection object that is
passed is a L<Plack::App::WebSocket::Connection> object 
augmented with the L<Dancer2::Plugin::WebSocket::Connection> role.


=head2 websocket_on_open sub { ... }

    websocket_on_open sub {
        my( $conn, $env ) = @_;
        ...;
    };


Code invoked when a new socket is opened. Gets the new 
connection
object and the Plack
C<$env> hash as arguments. 


=head1 websocket_on_close sub { ... }

    websocket_on_close sub {
        my( $conn ) = @_;
        ...;
    };


Code invoked when a new socket is opened. Gets the 
connection object as argument.

=head2 websocket_on_error sub { ... }

    websocket_on_error sub {
        my( $env ) = @_;
        ...;
    };


Code invoked when an error  is detected. Gets the Plack
C<$env> hash as argument and is expected to return a 
Plack triplet.

If not explicitly set, defaults to

    websocket_on_error sub {
        my $env = shift;
        return [ 
            500,
            ["Content-Type" => "text/plain"],
            ["Error: " . $env->{"plack.app.websocket.error"}]
        ];
    };

=head2 websocket_on_message sub { ... }

    websocket_on_error sub {
        my( $conn, $message ) = @_;
        ...;
    };


Code invoked when a message is received. Gets the connection
object and the message as arguments.

=cut

has 'on_'.$_ => (
    is => 'rw',
    plugin_keyword => 'websocket_on_'.$_,
    default => sub { sub { } },
) for qw/
    open
    message
    close
/;

has 'on_error' => (
    is => 'rw',
    plugin_keyword => 'websocket_on_error',
    default => sub { sub {
            my $env = shift;
            return [500,
                    ["Content-Type" => "text/plain"],
                    ["Error: " . $env->{"plack.app.websocket.error"}]];
        }
    },
);

=head2 websocket_url

Returns the full url of the websocket mountpoint.

    # assuming host is 'localhost:5000'
    # and the mountpoint is '/ws'
    print websocket_url;  # => ws://localhost:5000/ws

=cut

sub websocket_url :PluginKeyword {
    my $self = shift;
    my $request = $self->app->request;
    my $address = 'ws://' . $request->host . $self->mount_path;

    return $address;
}

=head2 websocket_mount 

Returns the mountpoint and the Plack app coderef to be
used for C<mount> in F<app.psgi>. See the SYNOPSIS.

=cut

sub websocket_mount :PluginKeyword {
    my $self = shift;

    return 
        $self->mount_path => Plack::App::WebSocket->new(
        on_error => sub { $self->on_error->(@_) },
        on_establish => sub {
            my $conn = shift; ## Plack::App::WebSocket::Connection object
            my $env = shift;  ## PSGI env

            Role::Tiny->apply_roles_to_object(
                $conn, 'Dancer2::Plugin::WebSocket::Connection'
            );
            $conn->serializer($self->serializer);

            $self->on_open->( $conn, $env, @_ );

            $conn->on(
                message => sub {
                    my( $conn, $message ) = @_;
                    if( my $s = $conn->serializer ) {
                        $message = $s->decode($message);
                    }
                    $self->on_message->( $conn, $message );
                },
                finish => sub {
                    $self->on_close->($conn);
                    $conn = undef;
                },
            );
        }
    )->to_app;

}

1;

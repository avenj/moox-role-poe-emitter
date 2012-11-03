use Test::More;
use strict; use warnings FATAL => 'all';
require_ok('MooX::Role::Pluggable::Constants');
use POE;

{
  package
   MyEmitter;

  use strict; use warnings FATAL => 'all';

  use POE;
  use Test::More;

  use MooX::Role::Pluggable::Constants;

  use Moo;

  with 'MooX::Role::POE::Emitter';

  sub BUILD {
    my ($self) = @_;

    $self->set_alias( 'SimpleEmitter' );

    $self->set_object_states(
      [
        $self => [ qw/
          shutdown
        / ],
      ],
    );
  }

  sub spawn {
    my ($self) = @_;
    $self->_start_emitter;
  }

  sub shutdown {
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    $self->_shutdown_emitter;
  }
}

my $emitter = MyEmitter->new;

POE::Session->create(
  package_states => [
    main => [ qw/
      _start
    / ],
  ],
);

$poe_kernel->run;

done_testing;

sub _start {
  $emitter->spawn;
  my $sess_id;
  ok( $sess_id = $emitter->session_id, 'session_id()' );
  $poe_kernel->post( $sess_id, 'subscribe' );

  $emitter->yield('shutdown');
}

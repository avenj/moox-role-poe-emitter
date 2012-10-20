use Test::More tests => 10;
use strict; use warnings FATAL => 'all';

use POE;

{
  package
   MyEmitter;

  use strict; use warnings FATAL => 'all';

  use POE;
  use Test::More;

  use MooX::Role::Pluggable::Constants;

  use Moo;

  with 'MooX::Role::Pluggable';

  sub BUILD {
    my ($self) = @_;

    $self->set_alias( 'SimpleEmitter' );

    $self->set_object_states(
      [
        $self => [
          'emitter_started',
          'emitter_stopped',
          'shutdown',
          'emitted_stuff',
        ],
      ],
    );

    $self->_start_emitter;
  }

  sub emitter_started {
    pass("Emitter started");
  }

  sub emitter_stopped {
    pass("Emitter stopped");
  }

  sub shutdown {
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    pass("shutdown called");

    $self->call( 'shutdown_emitter' );
  }

  sub emitted_stuff {
    my ($kernel, $self, $arg) = @_[KERNEL, OBJECT, ARG0];
    cmp_ok($arg, 'eq', 'test', 'emitted_stuff has correct argument' );
  }

  sub P_things {
    my ($self, $emitter, $first) = @_;
    isa_ok( $emitter, 'MyEmitter' );
    ok( $emitter->does('MooX::Role::Pluggable'), 'Emitter is Pluggable' );
    is( $$first, 1, "P_things had expected args" );
  }

}

POE::Session->create(
  package_states => [
    main => [ qw/

      _start

      emitted_registered

      emitted_test_emit

    / ],
  ],
);

$poe_kernel->run;

sub _start {
  my $emitter = MyEmitter->new;
  my $sess_id;
  ok( $sess_id = $emitter->session_id, 'session_id()' );
  $poe_kernel->post( $sess_id, 'register' );
}

sub emitted_registered {
  ## Test 'registered' ev
  isa_ok( $_[ARG0], 'MyEmitter' );
  ## Test process()
  $_[ARG0]->process( 'things', 1 );
  ## Test emit()
  $_[ARG0]->emit( 'test_emit', 1 );
  $_[ARG0]->emit( 'stuff', 'test' );
}

sub emitted_test_emit {
  ## emit() received
  is( $_[ARG0], 1, 'emitted_test()' );
  $poe_kernel->post( $_[SENDER], 'shutdown' );
}

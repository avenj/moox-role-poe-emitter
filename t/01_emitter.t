use Test::More;
use strict; use warnings FATAL => 'all';
require_ok('MooX::Role::Pluggable::Constants');
use POE;

my $got      = {};
my $expected = map {; $_ => 1 } (
  "emitted_stuff fired",
  "emitted_stuff correct arg",
);

{ package MyEmitter;

  use strict; use warnings FATAL => 'all';
  use Test::More;

  use Moo;
  use POE;

  use MooX::Role::Pluggable::Constants;

  with 'MooX::Role::POE::Emitter';

  sub BUILD {
    my ($self) = @_;

    $self->set_alias( 'SimpleEmitter' );

    $self->set_object_states(
      [
        $self => [ qw/
          emitter_started
          emitter_stopped
          shutdown
          emitted_stuff
          timed
          timed_fail
        / ],
      ],
    );

    $self->_start_emitter;
  }

  sub emitter_started {
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    $self->call('subscribe', 'stuff');
  }

  sub emitter_stopped {
    my ($kernel, $self) = @_[KERNEL, OBJECT];

  }

  sub shutdown {
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    $self->yield( 'shutdown_emitter' );
  }

  sub emitted_stuff {
    my ($kernel, $self, $arg) = @_[KERNEL, OBJECT, ARG0];
    $got->{'emitted_stuff fired'} = 1;
    $got->{'emitted_stuff correct arg'} = 1
      if $arg eq 'test';
  }

  sub P_things {
    my ($self, $emitter, $first) = @_;

    EAT_NONE
  }


  sub timed {

  }

  sub timed_fail {
    fail("timer should have been deleted");
  }

}

{ package MyPlugin;
  use strict; use warnings;
  use Test::More;
  use MooX::Role::Pluggable::Constants;

  sub new { bless [], shift }

  sub Emitter_register {
    my ($self, $core) = splice @_, 0, 2;

    $core->subscribe( $self, 'NOTIFY', 'all' );
    $core->subscribe( $self, 'PROCESS', 'all' );

    EAT_NONE
  }

  sub Emitter_unregister {

    EAT_NONE
  }

  sub P_from_default {
    my ($self, $core) = splice @_, 0, 2;

    EAT_NONE
  }

  sub N_eatclient {

    EAT_CLIENT
  }

  sub N_stuff {
    my ($self, $core) = splice @_, 0, 2;

    EAT_NONE
  }

  sub N_plugin_added {
    EAT_NONE
  }
}


POE::Session->create(
  package_states => [
    main => [ qw/

      _start

      emitted_registered

      emitted_test_emit
      emitted_eatclient
    / ],
  ],
);

$poe_kernel->run;

is_deeply($got, $expected);
done_testing;

sub _start {
  my $emitter = MyEmitter->new;

  my $sess_id = $emitter->session_id;
  ok( $sess_id > 0, 'session_id() returns positive int' );

  $poe_kernel->post( $sess_id, 'subscribe' );

  $emitter->plugin_add( 'MyPlugin', MyPlugin->new );

  ## Test process()

  ## Test emit() / emit_now()

  ## Test yield/call, named and anon CBs

  ## Test named state timers

  ## Test anon coderef timers
#  $emitter->timer( 0,
#    sub { pass("Anon coderef callback in timer") },
#  );

  ## Test timer_del()
#  my $todel = $emitter->timer( 1, 'timed_fail' );
#  $emitter->timer_del($todel);

  ## Test _emitter_default
#  $poe_kernel->post( $emitter->alias, 'from_default', 'test' );

  ## Done.
  $emitter->yield('shutdown');
}

sub emitted_registered {
  ## Test 'registered' ev
}

sub emitted_test_emit {
  ## emit() received
}

sub emitted_eatclient {
  fail("Should not have received EAT_CLIENT event");
}

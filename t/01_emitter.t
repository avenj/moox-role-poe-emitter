use Test::More;
use strict; use warnings FATAL => 'all';
require_ok('MooX::Role::Pluggable::Constants');
use POE;

## FIXME tests for internal '_pluggable_event' events

my $emitter_got;
my $emitter_expect = {
  'emitter started'            => 1,
  'emitter got PROCESS event'  => 1,
  'PROCESS event correct arg'  => 1,
  'emitter got emit event'     => 1,
  'emitter got emit_now event' => 1,
  'emitter got timed event'    => 1,
  'timed event correct arg'    => 1,
};

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
          emitter_started
          emitted_emit_event
          emitted_emit_now_event
          timed
          timed_fail
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
    $self->call('unsubscribe', 'all');
    $self->_shutdown_emitter;
  }

  sub emitter_started {
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $emitter_got->{'emitter started'}++;
    $self->call('subscribe');
  }

  sub emitted_emit_event {
    $emitter_got->{'emitter got emit event'}++;
  }

  sub emitted_emit_now_event {
    pass "Got emitted_emit_now_event";
    $emitter_got->{'emitter got emit_now event'}++;
  }

  sub P_processed {
    my ($self, $emitter, $arg) = @_;
    $emitter_got->{'emitter got PROCESS event'}++;
    $emitter_got->{'PROCESS event correct arg'}++
      if $$arg == 1;
    EAT_NONE
  }

  sub timed {
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $emitter_got->{'emitter got timed event'}++;
    $emitter_got->{'timed event correct arg'}++
      if $_[ARG0] == 1;
  }

  sub timed_fail {
    fail("timer should have been deleted!");
  }
}

my $plugin_got;
my $plugin_expect = {
  'register called'            => 1,
  'unregister called'          => 1,
  'got emit event'             => 1,
  'got emit_now event'         => 1,
  'got process event'          => 1,
  'PROCESS event correct arg'  => 1,
  'got _emitter_default event' => 1,
  'default event args correct' => 1,
};

{
  package
    MyPlugin;
  use strict; use warnings FATAL => 'all';
  use MooX::Role::Pluggable::Constants;

  sub new { bless [], shift }

  sub Emitter_register {
    my ($self, $core) = @_;
    $plugin_got->{'register called'}++;
    $core->subscribe( $self, 'NOTIFY', 'all');
    $core->subscribe( $self, 'PROCESS', 'all');
    EAT_NONE
  }

  sub Emitter_unregister {
    $plugin_got->{'unregister called'}++;
    EAT_NONE
  }

  sub N_emit_event {
    $plugin_got->{'got emit event'}++;
    EAT_NONE
  }

  sub N_emit_now_event {
    $plugin_got->{'got emit_now event'}++;
    EAT_NONE
  }

  sub N_eat_client {
    EAT_CLIENT
  }

  sub P_processed {
    my ($self, $emitter, $arg) = @_;
    $plugin_got->{'got process event'}++;
    $plugin_got->{'PROCESS event correct arg'}++
      if $$arg == 1;
    EAT_NONE
  }

  sub P_from_default {
    my ($self, $emitter, $arg) = @_;
    $plugin_got->{'got _emitter_default event'}++;
    $plugin_got->{'default event args correct'}++
      if $$arg eq 'test';
    EAT_NONE
  }
}

my $listener_got;
my $listener_expect = {
  'got emit event'                  => 1,
  'got emit_now event'              => 1,
  'CODE ref in yield'               => 1,
  'CODE ref in yield args correct'  => 1,
  'CODE ref timer fired'            => 1,
  'CODE ref present in timer STATE' => 1,
  'CODE ref timer args correct'     => 1,
};



my $emitter = MyEmitter->new;


sub _start {
  $emitter->spawn;
  my $sess_id;

  ## session_id()
  ok( $sess_id = $emitter->session_id, 'session_id()' );

  ## plugin load
  ok( $emitter->plugin_add('MyPlugin', MyPlugin->new), 'plugin_add()' );

  ## subscribe to all
  $poe_kernel->post( $sess_id, 'subscribe' );

  ## process() by Emitter and plugins
  $emitter->process('processed', 1);

  ## emit() to all w/ EAT_NONE
  $emitter->emit('emit_event', 1);

  ## emit_now() to all w/ EAT_NONE
  $emitter->emit_now('emit_now_event', 1);

  ## emit() w/ EAT_CLIENT, emitter and plugins only
  $emitter->emit('eat_client');

  $emitter->yield(
    sub {
      my ($sub_kern, $sub_obj) = @_[KERNEL, OBJECT];
      $listener_got->{'CODE ref in yield'}++;
      $listener_got->{'CODE ref in yield args correct'}++
        if $_[ARG0] eq 'one' and $_[ARG1] eq 'two';
    }, 'one', 'two'
  );

  $emitter->timer( 0, 'timed', 1 );

  my $timer_id = $emitter->timer( 1, 'timed_fail' );
  ok( $emitter->timer_del($timer_id), 'timer_del()' );

  my($timer_cb_res, $timer_cb_args);
  $emitter->timer( 0,
    sub {
      my ($sub_kern, $sub_obj) = @_[KERNEL, OBJECT];
      fail("Expected a MyEmitter but got $sub_obj")
        unless $sub_obj->isa('MyEmitter');
      my $this_cb = $_[STATE];

      $listener_got->{'CODE ref timer fired'}++;
      $listener_got->{'CODE ref present in timer STATE'}++
        if ref $this_cb eq 'CODE';
      $listener_got->{'CODE ref timer args correct'}++
        if $_[ARG0] eq 'some' and $_[ARG1] eq 'arg';
    },
    'some', 'arg'
  );

  $poe_kernel->post( $emitter->alias, 'from_default', 'test' );

  $emitter->set_alias( 'Stuff' );
  cmp_ok( $emitter->alias, 'eq', 'Stuff', 'set_alias() attrib changed' );
  ok( $poe_kernel->alias_resolve('Stuff'), 'set_alias() successful' );

  $emitter->yield('shutdown');
}

sub emitted_registered {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $emitter = $_[ARG0];

  pass "Got emitted_registered";
}

sub emitted_emit_event {
  $listener_got->{'got emit event'}++;
}

sub emitted_emit_now_event {
  $listener_got->{'got emit_now event'}++;
}

sub emitted_eat_client {
  fail("Should not have received EAT_CLIENT event");
}

POE::Session->create(
  package_states => [
    main => [ qw/
      _start
      emitted_registered
      emitted_emit_event
      emitted_emit_now_event
      emitted_eat_client
    / ],
  ],
);

$poe_kernel->run;

is_deeply($emitter_got, $emitter_expect,
  'Got expected results from Emitter'
);

is_deeply($plugin_got, $plugin_expect,
  'Got expected results from Plugin'
);

is_deeply($listener_got, $listener_expect,
  'Got expected results from Listener'
);

done_testing;

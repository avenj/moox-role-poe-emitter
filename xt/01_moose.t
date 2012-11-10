use Test::More tests => 6;
use Test::Exception;
use strict; use warnings FATAL => 'all';

{
  local $@;
  eval { require Moose; 1 }
    or BAIL_OUT("Test requires Moose");
}

{
  package
    MyEmitter;
  use strict; use warnings FATAL => 'all';
  use Moose;

  ## Turns out this should pass as-is ..
  ## .. but a Moo bug means you need:
  ##  'with "MooX::Role::Pluggable"';
  ##  'with "MooX::Role::POE::Emitter"';
  ## FIXME depend on newer Moo if RT bug gets fixed
  with 'MooX::Role::POE::Emitter';

  sub BUILD {
    my ($self) = @_;
    $self->_start_emitter;
  }

  sub shutdown {
    my ($self) = @_;
    $self->_shutdown_emitter;
  }
  __PACKAGE__->meta->make_immutable;
}

use POE;
POE::Session->create(
  package_states => [
    main => [
     qw/
       _start
       emitted_registered
       emitted_test
     /,
    ],
  ],
);

$poe_kernel->run;

sub _start {
  my $emitter = new_ok( 'MyEmitter' );
  $poe_kernel->post( $emitter->session_id, 'subscribe' );
  ok( $emitter->does('MooX::Role::POE::Emitter'), 'Emitter does Role' );
  $emitter->_pluggable_event( 'test', 1 );
  $emitter->emit( 'test', 2 );
  $emitter->yield(sub { pass("Anon callback") });
  $emitter->shutdown;
}

sub emitted_registered {
  pass("Got emitted_registered");
}

sub emitted_test {
  pass("Got emitted_test $_[ARG0]");
}

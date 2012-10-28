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
  with 'MooX::Role::Pluggable';
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
  ok( $emitter->does('MooX::Role::POE::Emitter'), 'Emitter does Role' );
  pass("Got _start");
  $poe_kernel->post( $emitter->session_id, 'subscribe' );
  $emitter->yield(sub { pass("Anon callback") });
  $emitter->shutdown;
}

sub emitted_registered {
  pass("Got emitted_registered");
  $_[ARG0]->emit( 'test' );
}

sub emitted_test {
  pass("Got emitted_test");
}

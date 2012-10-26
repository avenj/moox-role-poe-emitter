use Test::More tests => 4;
use Test::Exception;
use strict; use warnings FATAL => 'all';

{
  package
    MyEmitter;
  use strict; use warnings FATAL => 'all';
  use Moo;
  with 'MooX::Role::POE::Emitter';
}

dies_ok( sub { MyEmitter->new(
    object_states => '',
  ) }, 'empty string object_states'
);

my $emitter = MyEmitter->new;

dies_ok( sub { $emitter->set_object_states(
    [ $emitter => [ '_start' ] ]
  ) }, 'disallowed handler'
);

dies_ok( sub { $emitter->timer }, 'empty timer() call' );
dies_ok( sub { $emitter->timer_del }, 'empty timer_del() call' );

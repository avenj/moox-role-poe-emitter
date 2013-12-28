package MooX::Role::POE::Emitter::RegisteredSession;
use Carp;

use Types::Standard -types;
use Moo;

has id => ( is => 'rw', required => 1 );

has refcount => ( is => 'rw', required => 1 );

1;

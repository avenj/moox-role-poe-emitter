package MooX::Role::POE::Emitter::RegisteredSession;
use Carp;
use Moo;
has id       => ( is => 'rw', required => 1 );
has refcount => ( is => 'rw', required => 1 );

1;

package POEx::ZMQ3::Role::Emitter;

use Carp;
use Moo::Role;

use namespace::clean;

with 'MooX::Role::POE::Emitter';

requires 'start', 'stop';

around '_start_emitter' => sub {
  my ($orig, $self) = splice @_, 0, 2;
  $self->set_event_prefix( 'zeromq_' ) unless $self->has_event_prefix;
  $self->set_pluggable_type_prefixes(+{
    PROCESS => 'P_Zmq',
    NOTIFY  => 'Zmq',
  }) unless $self->has_pluggable_type_prefixes;

  $self->$orig(@_);
};

sub _stop_emitter { shift->_shutdown_emitter(@_) }


1;

=pod

=head1 NAME

POEx::ZMQ3::Role::Emitter - Event emitter for POEx::ZMQ3

=head1 SYNOPSIS

  package MyZMQServer;
  use Moo;
  with 'POEx::ZMQ3::Role::Emitter';
  with 'POEx::ZMQ3::Role::Sockets';

  sub start {
    my ($self) = @_;
    # ... set up zeromq connections, etc ...
    $self->_start_emitter;
  }

  sub stop {
    my ($self) = @_;
    $self->process( 'stop' );
    ## -> dispatched to loaded plugins as Zmq_stop
    $self->clear_all_zmq_sockets;
    $self->_shutdown_emitter;
  }

  sub zmq_message_ready {
    my ($self, $alias, $zmsg, $data) = @_;
    $self->emit( 'got_msg', $data );
    # -> dispatched to loaded plugins as Zmq_got_msg
    #    (synchronously)
    # -> emitted to subscribed POE::Session(s) as zeromq_got_msg
    #    (async)
  }

=head1 DESCRIPTION

This is a small wrapper for L<MooX::Role::POE::Emitter>, providing some sane
defaults for a L<POEx::ZMQ3> Emitter:

  ->event_prefix eq 'zeromq_'
  ->pluggable_type_prefixes eq +{
      PROCESS => 'P_Zmq',
      NOTIFY  => 'Zmq',
    }

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut

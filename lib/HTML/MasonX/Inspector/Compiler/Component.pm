package HTML::MasonX::Inspector::Compiler::Component;

use strict;
use warnings;

our $VERSION = '0.01';

use Scalar::Util ();

use UNIVERSAL::Object;
our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
our %HAS; BEGIN {
    %HAS = (
        name           => sub { die 'A `name` is required' },
        type           => sub { die 'A `type` is required' },
        args           => sub { +[] }, # ArrayRef[ HTML::MasonX::Inspector::Compiler::Component::Arg ]
        attributes     => sub { +{} }, # HashRef
        flags          => sub { +{} }, # HashRef
        methods        => sub { +{} }, # HashRef[ HTML::MasonX::Inspector::Compiler::Method ]
        sub_components => sub { +{} }, # HashRef[ HTML::MasonX::Inspector::Compiler::SubComponent ]
        body           => sub {     }, # HTML::MasonX::Inspector::Util::Perl
        blocks         => sub { +{} }, # HashRef[ HTML::MasonX::Inspector::Util::Perl ]
    )
}

sub BUILD {
    my ($self, $params) = @_;

    # normalise this ...
    $self->{type} = lc $self->{type};
    # now check it ...
    Carp::confess('The `type` must be one of the following (sub, main, method) not ('.$self->{type}.')')
        unless $self->{type} =~ /(sub|main|method)/;
}

sub name { $_[0]->{name} }
sub type { $_[0]->{type} }

sub args           { $_[0]->{args}           }
sub attributes     { $_[0]->{attributes}     }
sub flags          { $_[0]->{flags}          }
sub methods        { $_[0]->{methods}        }
sub sub_components { $_[0]->{sub_components} }

sub body   { $_[0]->{body}   }
sub blocks { $_[0]->{blocks} }

## ...

1;

__END__

=pod

=head1 NAME

HTML::MasonX::Inspector::Compiler::Attr - HTML::Mason::Compiler sea cucumber guts

=head1 DESCRIPTION

=cut
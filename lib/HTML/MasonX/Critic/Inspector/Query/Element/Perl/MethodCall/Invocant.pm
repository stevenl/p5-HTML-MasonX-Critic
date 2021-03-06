package HTML::MasonX::Critic::Inspector::Query::Element::Perl::MethodCall::Invocant;
# ABSTRACT: Query result objects representing the invocant of a Perl method call

use strict;
use warnings;

our $VERSION = '0.01';

use Carp         ();
use Scalar::Util ();

use UNIVERSAL::Object;
use HTML::MasonX::Critic::Inspector::Query::Element;
our @ISA;  BEGIN { @ISA = ('UNIVERSAL::Object') }
our @DOES; BEGIN { @DOES = ('HTML::MasonX::Critic::Inspector::Query::Element') }
our %HAS;  BEGIN {
    %HAS = (
        ppi => sub { die 'A `ppi` node is required' },
    )
}

sub BUILD {
    my ($self, $params) = @_;

    Carp::confess('The `ppi` node must be an instance of `PPI::Token::Word` or `PPI::Token::Symbol`, not '.ref($self->{ppi}))
        unless Scalar::Util::blessed( $self->{ppi} )
            && ($self->{ppi}->isa('PPI::Token::Symbol') || $self->{ppi}->isa('PPI::Token::Word'));
}

sub ppi { $_[0]->{ppi} }


# Element API
sub source        { $_[0]->{ppi}->content             }
sub filename      { $_[0]->{ppi}->logical_filename    }
sub line_number   { $_[0]->{ppi}->logical_line_number }
sub column_number { $_[0]->{ppi}->column_number       }

# ...

sub name       { $_[0]->{ppi}->content                 }
sub is_virtual { $_[0]->{ppi}->isa('PPI::Token::Word') }

1;

__END__

=pod

=head1 DESCRIPTION

=cut

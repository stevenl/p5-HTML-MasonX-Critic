package HTML::MasonX::Critic::Inspector::Query::Element::Perl::SubroutineCall;
# ABSTRACT: Query result objects representing a Perl subroutine call

use strict;
use warnings;

our $VERSION = '0.01';

use Carp                ();
use Scalar::Util        ();
use Perl::Critic::Utils ();

use UNIVERSAL::Object;
use HTML::MasonX::Critic::Inspector::Query::Element;
our @ISA;  BEGIN { @ISA = ('UNIVERSAL::Object') }
our @DOES; BEGIN { @DOES = ('HTML::MasonX::Critic::Inspector::Query::Element') }
our %HAS;  BEGIN {
    %HAS = (
        ppi       => sub { die 'A `ppi` node is required' },
        # private data
        _invocant => sub {},
    )
}

sub BUILD {
    my ($self, $params) = @_;

    Carp::confess('The `ppi` node must be an instance of `PPI::Token::Word`, not '.ref($self->{ppi}))
        unless Scalar::Util::blessed( $self->{ppi} )
            && $self->{ppi}->isa('PPI::Token::Word');
}

sub ppi { $_[0]->{ppi} }

# Element API
sub highlight     { $_[0]->literal                    }
sub source        { $_[0]->{ppi}->content             }
sub filename      { $_[0]->{ppi}->logical_filename    }
sub line_number   { $_[0]->{ppi}->logical_line_number }
sub column_number { $_[0]->{ppi}->column_number       }

# ...

sub literal { $_[0]->{ppi}->literal }

sub is_built_in {
    Perl::Critic::Utils::is_perl_builtin( $_[0]->{ppi} )
}

sub is_fully_qualified_call {
    my ($self) = @_;
    return index( $self->literal, '::' ) >= 0;
}

sub package_name {
    my ($self) = @_;

    # split it into parts ...
    my @namespace = split /\:\:/ => $self->literal;

    # pop off the last part (the sub name)
    pop @namespace;

    # if we have nothing left, oh well
    return undef unless @namespace;

    # but if we do, make it a package again ...
    return join '::' => @namespace;
}

sub name {
    my ($self) = @_;

    if ( $self->is_fully_qualified_call ) {
        return (split /\:\:/ => $self->literal)[-1]
    }
    else {
        return $self->literal;
    }
}



1;

__END__

=pod

=head1 DESCRIPTION

=cut

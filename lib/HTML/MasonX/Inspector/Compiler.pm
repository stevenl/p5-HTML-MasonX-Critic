package HTML::MasonX::Inspector::Compiler;

use strict;
use warnings;

our $VERSION = '0.01';

use Clone ();

use HTML::MasonX::Inspector::Compiler::Arg;
use HTML::MasonX::Inspector::Compiler::Flag;
use HTML::MasonX::Inspector::Compiler::Attr;
use HTML::MasonX::Inspector::Compiler::Method;
use HTML::MasonX::Inspector::Compiler::Def;

use HTML::MasonX::Inspector::Util::Perl;

use UNIVERSAL::Object;
our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
our %HAS; BEGIN {
    %HAS = (
        interpreter => sub { die 'An `interpreter` is required' },
        path        => sub { die 'A `path` is required' },
        # ...
        _compiler => sub {},
    )
}

sub BUILD {
    my ($self, $params) = @_;

    my $path = $self->{path};

    # prep this before passing to Mason ...
    $path = $path->stringify
        if Scalar::Util::blessed( $path )
        && $path->isa('Path::Tiny');

    my $interp   = $self->{interpreter};
    my $compiler = $interp->compiler;
    my $source   = $interp->resolve_comp_path_to_source( $path );

    ## -----------------------------------
    ## WARNING!!!
    ## -----------------------------------
    ## This horror is what happens inside
    ## the compiler, it is gross, but it
    ## has to be done here. It makes me sad.
    ## -----------------------------------
    local $compiler->{current_compile} = {};
    local $compiler->{main_compile}    = $compiler->{current_compile};
    local $compiler->{paused_compiles} = [];
    local $compiler->{comp_path}       = $source->comp_path;

    $compiler->lexer->lex(
        comp_source => $source->comp_source,
        name        => $source->friendly_name,
        compiler    => $compiler
    );

    ## -----------------------------------
    ## *sigh*
    ## -----------------------------------
    ## Now we need to freeze the state of
    ## the compiler because the `local`
    ## stuff above goes out of scope once
    ## we return from this BUILD. I weep.
    ## -----------------------------------
    $self->{_compiler} = Clone::clone( $compiler );

    #use Data::Dumper;
    #die Dumper $self->{_compiler};
}

## access stuff ...

sub comp_root            {    $_[0]->{_compiler}->{comp_root}            }
sub object_id            {    $_[0]->{_compiler}->object_id              }
sub allow_globals        {    $_[0]->{_compiler}->allow_globals          }
sub default_escape_flags { @{ $_[0]->{_compiler}->default_escape_flags } }

## collect info ...

sub get_args {
    my ($self) = @_;

    my $args = $self->{_compiler}->{main_compile}->{args};

    if ( defined $args && @$args ) {
        return map
            HTML::MasonX::Inspector::Compiler::Arg->new(
                sigil           => $_->{type},
                symbol          => $_->{name},
                default_value   => $_->{default},
                type_constraint => $_->{type_constraint},
                line_number     => $_->{line},
            ), @{$args}
        ;
    }

    return;
}

sub get_flags {
    my ($self) = @_;

    my $flags = $self->{_compiler}->{main_compile}->{flags};

    if ( defined $flags && keys %$flags ) {
        return map
            HTML::MasonX::Inspector::Compiler::Flag->new(
                key   => $_,
                value => $flags->{ $_ },
            ), sort keys %$flags
    }

    return;
}

sub get_attrs {
    my ($self) = @_;

    my $attr = $self->{_compiler}->{main_compile}->{attr};

    if ( defined $attr && keys %$attr ) {
        return map
            HTML::MasonX::Inspector::Compiler::Attr->new(
                key   => $_,
                value => $attr->{ $_ },
            ), sort keys %$attr
    }

    return;
}

sub get_methods {
    my ($self) = @_;

    my $methods = $self->{_compiler}->{main_compile}->{method};

    if ( defined $methods && keys %$methods ) {
        return map
            HTML::MasonX::Inspector::Compiler::Method->new(
                name => $_,
                args => [
                    map
                        HTML::MasonX::Inspector::Compiler::Arg->new(
                            sigil           => $_->{type},
                            symbol          => $_->{name},
                            default_value   => $_->{default},
                            type_constraint => $_->{type_constraint},
                            line_number     => $_->{line},
                        ), @{$methods->{$_}->{args}}
                ],
                body => HTML::MasonX::Inspector::Util::Perl->new(
                    source => \($methods->{$_}->{body})
                ),
            ), keys %$methods
    }

    return;
}

sub get_defs {
    my ($self) = @_;

    my $defs = $self->{_compiler}->{main_compile}->{def};
    #use Data::Dumper; die Dumper $defs;

    if ( defined $defs && keys %$defs ) {
        return map
            HTML::MasonX::Inspector::Compiler::Def->new(
                name => $_,
                args => [
                    map
                        HTML::MasonX::Inspector::Compiler::Arg->new(
                            sigil           => $_->{type},
                            symbol          => $_->{name},
                            default_value   => $_->{default},
                            type_constraint => $_->{type_constraint},
                            line_number     => $_->{line},
                        ), @{$defs->{$_}->{args}}
                ],
                body => HTML::MasonX::Inspector::Util::Perl->new(
                    source => \($defs->{$_}->{body})
                ),
            ), keys %$defs
    }

    return;
}

sub get_blocks {
    my ($self) = @_;

    my $blocks = $self->{_compiler}->{main_compile}->{blocks};

    my %blocks;

    # NOTE:
    # it is important to note that the main block
    # is basically a combination of any <%perl>
    # blocks as well as any HTML with embedded
    # templates in it.
    if ( $self->{_compiler}->{main_compile}->{body} ) {
        $blocks{main} = [
            HTML::MasonX::Inspector::Util::Perl->new(
                source => \($self->{_compiler}->{main_compile}->{body})
            )
        ];
    }

    $blocks{once}    = [ map HTML::MasonX::Inspector::Util::Perl->new(source => \$_), @{ $blocks->{once}    } ] if @{ $blocks->{once}    };
    $blocks{init}    = [ map HTML::MasonX::Inspector::Util::Perl->new(source => \$_), @{ $blocks->{init}    } ] if @{ $blocks->{init}    };
    $blocks{filter}  = [ map HTML::MasonX::Inspector::Util::Perl->new(source => \$_), @{ $blocks->{filter}  } ] if @{ $blocks->{filter}  };
    $blocks{cleanup} = [ map HTML::MasonX::Inspector::Util::Perl->new(source => \$_), @{ $blocks->{cleanup} } ] if @{ $blocks->{cleanup} };
    $blocks{shared}  = [ map HTML::MasonX::Inspector::Util::Perl->new(source => \$_), @{ $blocks->{shared}  } ] if @{ $blocks->{shared}  };

    return %blocks;
}

1;

__END__

=pod

=head1 NAME

HTML::MasonX::Inspector::Compiler - HTML::Mason::Compiler sea cucumber

=head1 DESCRIPTION



=cut
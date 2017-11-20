package HTML::MasonX::Sloop;

use strict;
use warnings;

our $VERSION = '0.01';

use Carp         ();
use List::Util   ();
use Scalar::Util ();

use HTML::Mason::Interp;

use HTML::MasonX::Sloop::Util qw[ calculate_checksum ];
use HTML::MasonX::Sloop::CompilerState;

use UNIVERSAL::Object;
our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
our %HAS; BEGIN {
    %HAS = (
        interpreter     => sub {},
        stubbed_methods => sub { +[] },
    )
}

sub BUILDARGS {
    my $class = shift;
    my $args  = $class->next::method( @_ );

    Carp::confess( 'Cannot create a new Mason Interpreter unless you supply `comp_root` parameter' )
        unless $args->{comp_root};

    Carp::confess( 'The `comp_root` must be a valid directory' )
        unless -e $args->{comp_root} && -d $args->{comp_root};

    return $args;
}

sub BUILD {
    my ($self, $params) = @_;

    # make the interpreter, but first
    # prepare the $params to pass to
    # Mason, and since we will alter it
    # we make a copy ...
    my %mason_args = %$params;

    # these are for us, so remove them ...
    delete $mason_args{stubbed_methods} if exists $mason_args{stubbed_methods};

    # prep the comp_root before passing to Mason ...
    $mason_args{comp_root} = $mason_args{comp_root}->stringify
        if Scalar::Util::blessed( $mason_args{comp_root} )
        && $mason_args{comp_root}->isa('Path::Tiny');

    # ...

    my $interpreter = HTML::Mason::Interp->new( %mason_args )
        || die "Could not load Mason Interpreter";

    # then set up the minimum needs to mock this run ...
    $interpreter->set_global(
        $_ => HTML::MasonX::Sloop::__EVIL__->new
    ) foreach map s/^[$@%]//r, $interpreter->compiler->allow_globals;

    # do this every time, just to be sure ...
    foreach my $method ( @{ $self->{stubbed_methods} } ) {
        no strict 'refs';
        no warnings 'once';
        # FIXME
        # this should just use the package name
        # that is configured in the Interpreter
        # but I forget where it is, so we can
        # do it later.
        # - SL
        *{ 'HTML::Mason::Commands::' . $method } = sub { };
    }

    $self->{interpreter} = $interpreter;
}

## delegated accessors ...

sub compiler      { $_[0]->{interpreter}->compiler  }
sub comp_root     { $_[0]->{interpreter}->comp_root }
sub allow_globals { $_[0]->compiler->allow_globals }

## do things ...

sub get_compiler_state_for_path {
    my ($self, $path) = @_;

    Carp::confess 'Can not resolve path ('.$path.')'
        unless !! $self->resolve_path( $path );

    return HTML::MasonX::Sloop::CompilerState->new(
        inspector => $self,
        path      => $path,
    );
}

sub resolve_path {
    my ($self, $path) = @_;

    $path = $path->stringify
        if Scalar::Util::blessed( $path )
        && $path->isa('Path::Tiny');

    return $self->{interpreter}->resolve_comp_path_to_source( $path );
}

sub get_object_code_for_path {
    my ($self, $path, %opts) = @_;

    my $interp   = $self->{interpreter};
    my $source   = $self->resolve_path( $path );
    my $obj_code = ${ $source->object_code( compiler => $interp->compiler ) };

    # unless they ask for the raw
    # source, always prepare it
    # for processing
    unless ( $opts{raw} ) {
        # this is variable, so it needs to be
        # stripped out since it is variable
        $obj_code =~ s/\s*\'load_time\'\s*\=\>\s*\d+\,//;

        # This is the comp_root and may be different
        # on different machines, so we should strip
        # it out now.
        my $comp_root = $interp->comp_root;
        $comp_root .= '/' unless $comp_root =~ /\/$/;
        $obj_code =~ s/\#line (\d+) \"$comp_root/\#line $1 \"/g;
    }

    return $obj_code;
}

sub get_object_code_checksum_for_path {
    my ($self, $path, %opts) = @_;
    return calculate_checksum( $self->get_object_code_for_path( $path, %opts ) );
}

## ------------------------------------------- ##
## Ugly internal stuff
## ------------------------------------------- ##

package    # ignore this, internal use only
  HTML::MasonX::Sloop::__EVIL__ {
    sub AUTOLOAD { return bless {}, __PACKAGE__ }
    sub DESTROY { () }
}

## ------------------------------------------- ##

1;

__END__

=pod

=head1 NAME

HTML::MasonX::Sloop - HTML::Mason Demolition Tools

=cut

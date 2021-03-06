package HTML::MasonX::Critic::Command;
# ABSTRACT: The guts of masoncritic command line tool

use strict;
use warnings;

our $VERSION = '0.01';

use Carp                ();
use Scalar::Util        ();
use Getopt::Long        ();
use JSON::MaybeXS       ();
use Term::ReadKey       ();
use Path::Tiny          ();
use Getopt::Long        ();
use IO::Prompt::Tiny    ();
use Term::ANSIColor     ':constants';

use HTML::MasonX::Critic;
use HTML::MasonX::Critic::Util::MasonFileFinder;

use UNIVERSAL::Object;
our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
our %HAS; BEGIN {
    %HAS = (
        dir                  => sub {},

        debug                => sub { $ENV{MASONCRITIC_DEBUG}            },
        verbose              => sub { $ENV{MASONCRITIC_VERBOSE}          },
        show_source          => sub { $ENV{MASONCRITIC_SHOW_SOURCE} // 0 },
        show_blame           => sub { $ENV{MASONCRITIC_SHOW_BLAME}  // 0 },
        use_color            => sub { $ENV{MASONCRITIC_USE_COLOR}   // 1 },
        as_json              => sub { $ENV{MASONCRITIC_AS_JSON}     // 0 },

        mason_critic_policy  => sub {},
        mason_critic_profile => sub {},

        perl_critic_policy   => sub {},
        perl_critic_profile  => sub {},

        ## private data
        _mason_critic => sub {},
        _file_finder  => sub {},
    )
}

sub BUILD {
    my ($self) = @_;

    Getopt::Long::GetOptions(
        'debug|d'                => \$self->{debug},
        'verbose|v'              => \$self->{verbose},
        'show-source'            => \$self->{show_source},
        'show-blame'             => \$self->{show_blame},
        'color'                  => \$self->{use_color},
        'json'                   => \$self->{as_json},

        'dir=s'                  => \$self->{dir},

        'mason-critic-policy=s'  => \$self->{mason_critic_policy},
        'mason-critic-profile=s' => \$self->{mason_critic_profile},

        'perl-critic-profile=s'  => \$self->{perl_critic_profile},
        'perl-critic-policy=s'   => \$self->{perl_critic_policy},
    );

    # do this first ...
    $ENV{ANSI_COLORS_DISABLED} = ! $self->{use_color};

    ## Check the args

    $self->usage('You must specify a --dir')
        unless defined $self->{dir};

    $self->usage('The --dir must be a valid directory.')
        unless -e $self->{dir} && -d $self->{dir};

    $self->usage('You cannot set a Perl::Critic policy *and* a profile')
        if defined $self->{perl_critic_policy}
        && defined $self->{perl_critic_profile};

    $self->usage('You cannot set a HTML::MasonX::Critic policy *and* a profile')
        if defined $self->{mason_critic_policy}
        && defined $self->{mason_critic_profile};

    if ( $self->{perl_critic_profile} ) {
        $self->usage('Unable to find the Perl::Critic profile at ('.$self->{perl_critic_profile}.')')
            unless -f $self->{perl_critic_profile};
    }


    if ( $self->{mason_critic_profile} ) {
        $self->usage('Unable to find the HTML::MasonX::Critic profile at ('.$self->{mason_critic_profile}.')')
            unless -f $self->{mason_critic_profile};
    }

    ## Build some sub-objects

    $self->{dir} = Path::Tiny::path( $self->{dir} )
        unless Scalar::Util::blessed( $self->{dir} )
            && $self->{dir}->isa('Path::Tiny');

    $self->{_file_finder}  = HTML::MasonX::Critic::Util::MasonFileFinder->new( root_dir => $self->{dir} );
    $self->{_mason_critic} = HTML::MasonX::Critic->new(
        comp_root => $self->{dir},
        config    => {
            map {
                $_ => $self->{ $_ }
            } qw[
                perl_critic_policy
                perl_critic_profile
                mason_critic_policy
                mason_critic_profile
            ]
        }
    );
}

## ...

sub usage {
    my ($self, $error) = @_;
    print $error, "\n" if $error;
    print <<'USAGE';
masoncritic [-dv] [long options...]
    --dir                  the root directory to look within
    --perl-critic-profile  set the Perl::Critic profile to use
    --perl-critic-policy   set the Perl::Critic policy to use
    --mason-critic-policy  set the HTML::MasonX::Critic policy to use
    --mason-critic-profile set the HTML::MasonX::Critic profile to use
    --color                turn on/off color in the output
    --json                 output the violations as JSON
    --show-source          include the Mason source code in the output when in verbose mode
    --show-blame           include git-blamed Mason source code in the output when in verbose mode
    -d --debug             turn on debugging
    -v --verbose           turn on verbosity
USAGE
    exit(0);
}

sub run {
    my ($self) = @_;

    my $root_dir    = $self->{dir};
    my $critic      = $self->{_mason_critic};
    my $all_files   = $self->{_file_finder}->find_all_mason_files( relative => 1 );

    while ( my $file = $all_files->next ) {

        if ( my @violations = $critic->critique( $file ) ) {

            print BOLD, "Found (".(scalar @violations).") violations in $file\n", RESET
                unless $self->{as_json};

            foreach my $violation ( @violations ) {
                $self->_display_violation( $root_dir, $file, $violation );
                next unless $self->{verbose};
                next if     $self->{as_json};
                if ( my $x = IO::Prompt::Tiny::prompt( FAINT('> next violation?', RESET), 'y') ) {
                    last if $x eq 'n';
                }
            }
        }
        else {
            print ITALIC, GREEN, "No violations in $file\n", RESET
                unless $self->{as_json};
        }
    }

    exit;
}

## ...

sub TERM_WIDTH () {
    return eval {
        local $SIG{__WARN__} = sub {''};
        ( Term::ReadKey::GetTerminalSize() )[0];
    } || 80
}

use constant HR_ERROR => ( '== ERROR ' . ( '=' x ( TERM_WIDTH - 9 ) ) );
use constant HR_DARK  => ( '=' x TERM_WIDTH );
use constant HR_LIGHT => ( '-' x TERM_WIDTH );

sub _display_violation {
    my ($self, $root_dir, $file, $violation) = @_;

    if ( $self->{as_json} ) {
        print JSON::MaybeXS->new->encode({
            comp_root     => $root_dir->stringify,
            filename      => $violation->logical_filename,
            line_number   => $violation->logical_line_number,
            column_number => $violation->column_number,
            policy        => $violation->policy,
            severity      => $violation->severity,
            source        => $violation->source,
            description   => $violation->description,
            explanation   => $violation->explanation,
        }), "\n";
    }
    else {
        if ( $self->{verbose} ) {
            print HR_DARK, "\n";
            print BOLD, RED, (sprintf "Violation: %s\n" => $violation->description), RESET;
            print HR_DARK, "\n";
            print sprintf "%s\n" => $violation->explanation;
            print HR_LIGHT, "\n";
            #if ( $DEBUG ) {
            #    print sprintf "%s\n" => $violation->diagnostics;
            #    print HR_LIGHT, "\n";
            #}
            print sprintf "  policy   : %s\n"           => $violation->policy;
            print sprintf "  severity : %d\n"           => $violation->severity;
            print sprintf "  location : %s @ <%d:%d>\n" => (
                $file,
                $violation->logical_line_number,
                $violation->column_number
            );
            print HR_LIGHT, "\n";
            print ITALIC, (sprintf "%s\n" => $violation->source), RESET;
            print HR_LIGHT, "\n";
            if ( $self->{show_source} || $self->{show_blame} ) {

                my $file_obj;

                if ( $self->{show_source} ) {
                    $file_obj = $violation->source_file;
                }
                elsif ( $self->{show_blame} ) {
                    $file_obj = $violation->blame_file( git_work_tree => $root_dir );
                    print ITALIC, YELLOW, (sprintf "... blame-ing %s\n" => $file), RESET;
                    print HR_LIGHT, "\n";
                }
                else {
                    ; # never happen
                }

                my @lines = $file_obj->get_violation_lines(
                    before => 5,
                    after  => 5,
                );

                # drop the first line if it is a blank
                if ( $lines[0]->line =~ /^\s*$/ ) {
                    shift @lines;
                }

                my $highlight = $violation->highlight;

                foreach my $line ( @lines ) {
                    if ( $line->in_violation ) {
                        my $source = $line->line;
                        if ( $highlight && $source ne $highlight ) {
                            my $highlighted = join '' => BLUE, $highlight, RED;
                            $source =~ s/$highlight/$highlighted/;
                        }
                        print BOLD, (sprintf '%s:> %s' => $line->metadata, (join '' => RED, $source)), RESET;
                    }
                    else {
                        print FAINT, (sprintf '%s:  %s' => $line->metadata, (join '' => RESET, $line->line)), RESET;
                    }
                }

                print HR_LIGHT, "\n";
            }
        }
        else {
            print RED, $violation, RESET;
        }
    }
}

1;

__END__

=pod

=head1 DESCRIPTION

=cut

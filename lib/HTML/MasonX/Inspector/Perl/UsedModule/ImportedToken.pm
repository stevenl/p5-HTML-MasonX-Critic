package HTML::MasonX::Inspector::Perl::UsedModule::ImportedToken;

use strict;
use warnings;

our $VERSION = '0.01';

use UNIVERSAL::Object;
our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
our %HAS; BEGIN {
    %HAS = (
        token => sub { die 'A `token` is required' },
    )
}

sub token   { $_[0]->{token} }
sub is_tag  { $_[0]->token =~ /^\:/ ? 1 : 0 }
sub is_name { $_[0]->is_tag ? 0 : 1 }

1;

__END__

=pod

=head1 NAME

HTML::MasonX::Inspector::Util::Perl - HTML::Mason::Compiler sea cucumber guts

=head1 DESCRIPTION

=cut

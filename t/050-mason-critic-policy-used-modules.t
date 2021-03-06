#!/usr/bin/env perl

use strict;
use warnings;

use Path::Tiny ();

use Test::More;
use Test::Fatal;

BEGIN {
    use_ok('HTML::MasonX::Critic');
}

my $MASON_FILE_NAME = '050-mason-critic-policy-used-modules.html';
my $COMP_ROOT       = Path::Tiny->tempdir;

$COMP_ROOT->child( $MASON_FILE_NAME )->spew(q[
<%once>
use Scalar::Util 'blessed', qw[ :Test foo bar ];
use List::Util   qw[ :All ];
use File::Spec   ();
</%once>
<%init>
require DateTime;
</%init>
]);

subtest '... testing UsedModules::ProhibitImportingTags policy' => sub {

    my $POLICY = 'HTML::MasonX::Critic::Policy::UsedModules::ProhibitImportingTags';

    my $critic = HTML::MasonX::Critic->new(
        comp_root => $COMP_ROOT,
        config    => {
            mason_critic_policy => $POLICY
        }
    );
    isa_ok($critic, 'HTML::MasonX::Critic');

    my @violations = $critic->critique( $MASON_FILE_NAME );

    is(scalar(@violations), 2, '... got two violations back');
    my ($scalar_util, $list_util) = @violations;

    subtest '... testing the Scalar::Util violation' => sub {
        is($scalar_util->source, q[use Scalar::Util 'blessed', qw[ :Test foo bar ];], '... got the expected source');
        is($scalar_util->line_number, 3, '... got the expected line number');
        is($scalar_util->column_number, 1, '... got the expected column number');
        is($scalar_util->filename, $COMP_ROOT->child( $MASON_FILE_NAME ), '... got the expected filename');
        is($scalar_util->policy, $POLICY, '... got the expected policy');
    };

    subtest '... testing the List::Util violation' => sub {
        is($list_util->source, q[use List::Util   qw[ :All ];], '... got the expected source');
        is($list_util->line_number, 4, '... got the expected line number');
        is($list_util->column_number, 1, '... got the expected column number');
        is($list_util->filename, $COMP_ROOT->child( $MASON_FILE_NAME ), '... got the expected filename');
        is($list_util->policy, $POLICY, '... got the expected policy');
    };

};

subtest '... testing UsedModules::EnsureDoNotCallImport policy' => sub {

    my $POLICY = 'HTML::MasonX::Critic::Policy::UsedModules::EnsureDoNotCallImport';

    my $critic = HTML::MasonX::Critic->new(
        comp_root => $COMP_ROOT,
        config    => {
            mason_critic_policy => $POLICY
        }
    );
    isa_ok($critic, 'HTML::MasonX::Critic');

    my @violations = $critic->critique( $MASON_FILE_NAME );

    is(scalar(@violations), 2, '... got two violations back');
    my ($scalar_util, $list_util) = @violations;

    subtest '... testing the Scalar::Util violation' => sub {
        is($scalar_util->source, q[use Scalar::Util 'blessed', qw[ :Test foo bar ];], '... got the expected source');
        is($scalar_util->line_number, 3, '... got the expected line number');
        is($scalar_util->column_number, 1, '... got the expected column number');
        is($scalar_util->filename, $COMP_ROOT->child( $MASON_FILE_NAME ), '... got the expected filename');
        is($scalar_util->policy, $POLICY, '... got the expected policy');
    };

    subtest '... testing the List::Util violation' => sub {
        is($list_util->source, q[use List::Util   qw[ :All ];], '... got the expected source');
        is($list_util->line_number, 4, '... got the expected line number');
        is($list_util->column_number, 1, '... got the expected column number');
        is($list_util->filename, $COMP_ROOT->child( $MASON_FILE_NAME ), '... got the expected filename');
        is($list_util->policy, $POLICY, '... got the expected policy');
    };

};

subtest '... testing UsedModules::EnsureOnlyInOnceBlocks policy' => sub {

    my $POLICY = 'HTML::MasonX::Critic::Policy::UsedModules::EnsureOnlyInOnceBlocks';

    my $critic = HTML::MasonX::Critic->new(
        comp_root => $COMP_ROOT,
        config    => {
            mason_critic_policy => $POLICY
        }
    );
    isa_ok($critic, 'HTML::MasonX::Critic');

    my @violations = $critic->critique( $MASON_FILE_NAME );

    is(scalar(@violations), 1, '... got one violation back');
    my ($datetime) = @violations;

    subtest '... testing the DateTime violation' => sub {
        is($datetime->source, q[require DateTime;], '... got the expected source');
        is($datetime->line_number, 8, '... got the expected line number');
        is($datetime->column_number, 1, '... got the expected column number');
        is($datetime->filename, $COMP_ROOT->child( $MASON_FILE_NAME ), '... got the expected filename');
        is($datetime->policy, $POLICY, '... got the expected policy');
    };

};

done_testing;


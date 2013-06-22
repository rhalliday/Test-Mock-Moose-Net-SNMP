#!/usr/bin/perl
use strict;
use warnings;

use FindBin qw( $Bin );
use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir);

use lib catdir(dirname($Bin), 'lib');

use Test::More tests => 17;
use Test::Exception;

use Test::Mock::Moose::Net::SNMP;

use Net::SNMP;

my $mock_net_snmp = Test::Mock::Moose::Net::SNMP->new();

$mock_net_snmp->set_varbindlist(
    [
        { '1.2.1.1' => 'test', '1.2.1.2' => 'test2', '1.2.1.3' => 'test3' },
        { '1.2.2.1' => 'tset', '1.2.2.2' => 'tset2', '1.2.2.3' => 'tset3' },
        { '1.2.2.1' => 'tset', '1.2.2.2' => 'tset2', '1.2.2.3' => 'tset3' }
    ]
);

# blocking mode
my $snmp = Net::SNMP->session(-hostname => 'blah', -community => 'blah');
my $result;
ok($result = $snmp->get_request(-varbindlist => ['1.2.1.1']), 'can call get_request in blocking mode');
is_deeply(
    $result,
    { '1.2.1.1' => 'test', '1.2.1.2' => 'test2', '1.2.1.3' => 'test3' },
    'first element of varbindlist is returned for get_request'
);
is_deeply($mock_net_snmp->get_option_val('get_request', '-varbindlist'), ['1.2.1.1'], 'mock object stores varbindlist');

# non-blocking mode
my $oid_result;
ok($snmp->get_request(-callback => [ \&getr_callback, \$oid_result ], -delay => 60, -varbindlist => ['1.2.2']),
    'calling get_request in non-blocking mode returns true');
is($oid_result, 'tset', q{get_request in non-blocking mode calls the call back});
is_deeply($mock_net_snmp->get_option_val('get_request', '-varbindlist'),
    ['1.2.2'], 'mock object stores varbindlist in non-blocking mode');
is_deeply($mock_net_snmp->get_option_val('get_request', '-delay'), 60, 'mock object stores delay in non-blocking mode');

ok($snmp->get_request(Callback => [ \&getr_callback, \$oid_result ], Delay => 60, Varbindlist => ['1.2.2']),
    'calling get_request with title case options returns true');
is($oid_result, 'tset', q{get_request in non-blocking mode calls the call back with title case option});
is_deeply($mock_net_snmp->get_option_val('get_request', 'Varbindlist'),
    ['1.2.2'], 'mock object stores Varbindlist in non-blocking mode with title case option');
is_deeply($mock_net_snmp->get_option_val('get_request', 'Delay'), 60, 'mock object stores Delay in non-blocking mode with title case option');

# check an error is created if there is no varbindlist
ok(!defined $snmp->get_request(-delay => 60), 'calling get_request without varbindlist returns undefined');
is($snmp->error(), '-varbindlist option not passed in to get_request', 'error message set to what we expect');
$mock_net_snmp->reset_values();

# check an error is created if there is no varbindlist
$mock_net_snmp->set_error('my error');
ok(!defined $snmp->get_request(-delay => 60),
    'calling get_request without varbindlist returns undefined, when user defines error');
is($snmp->error(), 'my error', 'error message set to what we expect, when user defines error');
$mock_net_snmp->reset_values();

# no more elements in varbindlist
ok(!defined $snmp->get_request(-varbindlist => ['1.2.2']), 'returns undef if there are no more elements');
is($snmp->error(), 'No more elements in varbindlist!', 'no more elements error set correctly');

sub getr_callback {
    my ($session, $or_ref) = @_;
    my $list = $session->var_bind_list();

    $$or_ref = $list->{'1.2.2.1'};
    return;
}

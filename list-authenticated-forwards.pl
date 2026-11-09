#!/usr/bin/perl
use strict;
use warnings;
our $module_name;

=head1 list-authenticated-forwards.pl

Lists mailboxes that use authenticated forwarding.

Prints one line per mailbox: virtual server, mailbox and the addresses its
authenticated mail is forwarded to. Limit the output to one virtual server
with C<--domain>. With C<--multiline> each mailbox is printed as a block,
which is easier to parse.

  virtualmin list-authenticated-forwards
  virtualmin list-authenticated-forwards --domain example.com --multiline

=cut

package virtualmin_authfwd;
if (!$module_name) {
	no warnings "once";
	$main::no_acl_check++;
	use warnings "once";
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
	my $pwd;
	if ($0 =~ /^(.*)\/[^\/]+$/) {
		chdir($pwd = $1);
		}
	else {
		chop($pwd = `pwd`);
		}
	$0 = "$pwd/list-authenticated-forwards.pl";
	require './authfwd-lib.pl';
	$< == 0 || die "list-authenticated-forwards must be run as root\n";
	}

my ($only, $multiline);
while (@ARGV) {
	my $a = shift(@ARGV);
	if ($a eq "--domain") { $only = shift(@ARGV); }
	elsif ($a eq "--multiline") { $multiline = 1; }
	else { die "usage: list-authenticated-forwards [--domain name] [--multiline]\n"; }
	}

&foreign_require("virtual-server", "virtual-server-lib.pl");
my @doms;
if ($only) {
	my $d = &virtual_server::get_domain_by("dom", $only);
	$d || die "Virtual server $only does not exist\n";
	@doms = ( $d );
	}
else {
	@doms = grep { $_->{'mail'} } &virtual_server::list_domains();
	}

my %all = &list_forwards();
my %seen;
foreach my $d (sort { $a->{'dom'} cmp $b->{'dom'} } @doms) {
	my %f = &domain_forwards($d);
	foreach my $k (sort keys %f) {
		$seen{$k}++;
		if ($multiline) {
			print "$k\n    Virtual server: $d->{'dom'}\n",
			      "    Forwarded to: ", join(", ", @{$f{$k}}), "\n";
			}
		else {
			print join("\t", $d->{'dom'}, $k, join(", ", @{$f{$k}})), "\n";
			}
		}
	}
# Entries whose mailbox no longer exists (only shown for the whole server)
if (!$only) {
	foreach my $k (sort grep { !$seen{$_} } keys %all) {
		print $multiline ? "$k\n    Virtual server: (no matching mailbox)\n".
				   "    Forwarded to: ".join(", ", @{$all{$k}})."\n"
				 : join("\t", "-", $k, join(", ", @{$all{$k}}))."\n";
		}
	}

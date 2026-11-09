#!/usr/bin/perl
use strict;
use warnings;
our $module_name;

=head1 migrate-forwards.pl

Moves existing "keep a local copy and forward" mailboxes to authenticated
forwarding.

Finds mailboxes whose Virtualmin forwarding both delivers locally and sends
to external addresses. By default it only lists them. With C<--apply> it adds
the external addresses to authenticated forwarding and removes them from the
normal Virtualmin forward (via C<virtualmin modify-user --del-forward>), so
each recipient keeps receiving mail exactly once. Limit it to one virtual
server with C<--domain>.

Mailboxes that only forward (no local copy) are not touched: the plugin needs
a local delivery to hook into.

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
	$0 = "$pwd/migrate-forwards.pl";
	require './authfwd-lib.pl';
	$< == 0 || die "migrate-forwards must be run as root\n";
	}

my ($apply, $only);
while (@ARGV) {
	my $a = shift(@ARGV);
	if ($a eq "--apply") { $apply = 1; }
	elsif ($a eq "--domain") { $only = shift(@ARGV); }
	else { die "usage: migrate-forwards.pl [--domain name] [--apply]\n"; }
	}

my $err = &check_requirements();
die "$err\n" if ($err);

&foreign_require("virtual-server", "virtual-server-lib.pl");
my @doms = $only ? ( &virtual_server::get_domain_by("dom", $only) )
		 : &virtual_server::list_domains();
@doms = grep { $_ && $_->{'mail'} } @doms;
die "No matching virtual servers with email\n" if (!@doms);

my $count = 0;
foreach my $d (@doms) {
	foreach my $u (&virtual_server::list_domain_users($d, 0, 1, 1, 1)) {
		my @to = @{$u->{'to'} || []};
		next if (!@to);
		my $local = grep { (&virtual_server::alias_type($_, $u->{'user'}))[0] == 10 } @to;
		my @ext = grep { !/^[\\|\/:.%]/ && /\@([^\@\s]+)$/ && !&is_hosted_domain($1) } @to;
		next if (!$local || !@ext);
		$count++;
		print "$d->{'dom'}\t$u->{'user'}\t", join(", ", @ext),
		      ($apply ? "\tmigrating" : ""), "\n";
		next if (!$apply);
		my @t = &get_forwards($u->{'user'});
		my %have = map { lc($_), 1 } @t;
		&set_forwards($u->{'user'}, [ @t, grep { !$have{lc $_} } @ext ]);
		foreach my $a (@ext) {
			my $out = &backquote_command(
				"virtualmin modify-user --domain ".quotemeta($d->{'dom'}).
				" --user ".quotemeta($u->{'user'}).
				" --del-forward ".quotemeta($a)." 2>&1");
			print "  WARNING: removing $a from the Virtualmin forward failed: $out"
				if ($?);
			}
		}
	}
&install_recipe() if ($apply && $count && !&recipe_installed());
print $count ? ($apply ? "Migrated $count mailbox(es).\n"
		       : "$count mailbox(es) can be migrated; run again with --apply.\n")
	     : "Nothing to migrate.\n";

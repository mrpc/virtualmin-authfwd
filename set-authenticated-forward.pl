#!/usr/bin/perl
use strict;
use warnings;
our ($module_name, %text);

=head1 set-authenticated-forward.pl

Changes the authenticated forwarding addresses of a mailbox.

Identify the mailbox with C<--domain> and C<--user>. Then add addresses with
one or more C<--add>, remove them with C<--remove>, or remove them all with
C<--clear>. An address in a domain hosted on this server, or one that is also a
normal Virtualmin forwarding destination of the mailbox, is refused.

  virtualmin set-authenticated-forward --domain example.com --user info --add someone@gmail.com
  virtualmin set-authenticated-forward --domain example.com --user info --clear

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
	$0 = "$pwd/set-authenticated-forward.pl";
	require './authfwd-lib.pl';
	$< == 0 || die "set-authenticated-forward must be run as root\n";
	}

my ($dname, $uname, $clear, @add, @del);
while (@ARGV) {
	my $a = shift(@ARGV);
	if ($a eq "--domain") { $dname = shift(@ARGV); }
	elsif ($a eq "--user") { $uname = shift(@ARGV); }
	elsif ($a eq "--add") { push(@add, shift(@ARGV)); }
	elsif ($a eq "--remove") { push(@del, shift(@ARGV)); }
	elsif ($a eq "--clear") { $clear = 1; }
	else { &usage(); }
	}
$dname && $uname || &usage();
@add || @del || $clear || &usage();

my $err = &check_requirements();
die "$err\n" if ($err);

&foreign_require("virtual-server", "virtual-server-lib.pl");
my $d = &virtual_server::get_domain_by("dom", $dname);
$d || die "Virtual server $dname does not exist\n";
$d->{'mail'} || die "Email is not enabled for $dname\n";
my ($u) = grep { $_->{'user'} eq $uname ||
		 &virtual_server::remove_userdom($_->{'user'}, $d) eq $uname }
	       &virtual_server::list_domain_users($d, 0, 0, 1, 1);
$u || die "Mailbox $uname does not exist in $dname\n";

my @t = $clear ? () : &get_forwards($u->{'user'});
my %del = map { lc($_), 1 } @del;
@t = grep { !$del{lc $_} } @t;
my %have = map { lc($_), 1 } @t;
push(@t, grep { !$have{lc $_}++ } @add);

# Same checks as the Edit Mailbox page
my %vfwd = map { lc($_), 1 } grep { !/^[\\|\/:.%]/ && /\@/ } @{$u->{'to'} || []};
foreach my $a (@add) {
	$a =~ /^[^\s\@]+\@([A-Za-z0-9.-]+\.[A-Za-z]{2,})$/ ||
		die &plain(&text('err_addr', $a))."\n";
	&is_hosted_domain($1) &&
		die &plain(&text('err_local', $a))."\n";
	$vfwd{lc($a)} &&
		die &plain(&text('err_dup', $a))."\n";
	}

&set_forwards($u->{'user'}, \@t);
&install_recipe() if (@t && !&recipe_installed());
print @t ? "$u->{'user'} now forwards authenticated mail to: ".join(", ", @t)."\n"
	 : "$u->{'user'} no longer uses authenticated forwarding\n";

sub usage
{
print STDERR "usage: set-authenticated-forward --domain name --user name\n",
	     "         [--add address]* [--remove address]* [--clear]\n";
exit(1);
}

sub plain
{
my ($s) = @_;
$s =~ s/<[^>]+>//g;
return $s;
}

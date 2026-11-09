# authfwd-lib.pl - shared functions for the Authenticated Forwarding plugin
# License: GPL-3.0-or-later
use strict;
use warnings;
our (%config, %text, $module_root_directory);

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

our $forwards_file = $config{'forwards_file'} || '/etc/authfwd/forwards';
our $procmailrc    = '/etc/procmailrc';
our $mark_begin    = '# BEGIN virtualmin-authfwd';
our $mark_end      = '# END virtualmin-authfwd';

# list_forwards() -> hash of mailbox user => [ addresses ]
sub list_forwards
{
my %rv;
my $lref = &read_file_lines($forwards_file, 1);
foreach my $l (@$lref) {
	next if ($l =~ /^\s*(#|$)/);
	my ($u, @t) = split(/\s+/, $l);
	$rv{$u} = \@t if (defined($u) && @t);
	}
return %rv;
}

# get_forwards(user) -> list of addresses
sub get_forwards
{
my ($user) = @_;
my %f = &list_forwards();
return $f{$user} ? @{$f{$user}} : ();
}

# set_forwards(user, &addresses) - an empty list removes the mailbox
sub set_forwards
{
my ($user, $addrs) = @_;
&lock_file($forwards_file);
my %f = &list_forwards();
if ($addrs && @$addrs) {
	$f{$user} = [ @$addrs ];
	}
else {
	delete($f{$user});
	}
my $dir = $forwards_file;
$dir =~ s/\/[^\/]+$//;
&make_dir($dir, 0755, 1) if (!-d $dir);
my $fh = "FWD";
&open_tempfile($fh, ">$forwards_file");
&print_tempfile($fh, "# Managed by the Virtualmin Authenticated Forwarding plugin.\n");
&print_tempfile($fh, "# <mailbox user> <address> [<address> ...]\n");
foreach my $u (sort keys %f) {
	&print_tempfile($fh, join(" ", $u, @{$f{$u}}), "\n");
	}
&close_tempfile($fh);
&set_ownership_permissions(undef, undef, 0644, $forwards_file);
&unlock_file($forwards_file);
&unflush_file_lines($forwards_file);	# drop the cached copy read above
}

# rename_forwards(olduser, newuser)
sub rename_forwards
{
my ($old, $new) = @_;
return if ($old eq $new);
my @t = &get_forwards($old);
return if (!@t);
&set_forwards($old, [ ]);
&set_forwards($new, \@t);
}

# recipe_lines() -> the procmail block, as a list of lines
sub recipe_lines
{
my $awk = &has_command("awk") || "/usr/bin/awk";
return ( $mark_begin." (do not edit; managed by the plugin)",
	 ":0c",
	 "* ? $awk -v u=\"\$LOGNAME\" '{k=\$1; gsub(\"@\",\"-\",k)} \$1==u||k==u{f=1} END{exit !f}' $forwards_file",
	 "| $module_root_directory/authfwd",
	 $mark_end );
}

# recipe_installed() -> 1 if the procmail block is present
sub recipe_installed
{
my $lref = &read_file_lines($procmailrc, 1);
return scalar(grep { index($_, $mark_begin) == 0 } @$lref) ? 1 : 0;
}

# install_recipe() - add or refresh the block before the first recipe, so it
# runs before Virtualmin's own delivery and spam rules.
sub install_recipe
{
&lock_file($procmailrc);
my $lref = &read_file_lines($procmailrc);
&strip_recipe($lref);
my $pos = 0;
for (my $i = 0; $i < @$lref; $i++) {
	if ($lref->[$i] =~ /^:0/) { $pos = $i; last; }
	$pos = $i + 1;
	}
splice(@$lref, $pos, 0, &recipe_lines());
&flush_file_lines($procmailrc);
&unlock_file($procmailrc);
}

# remove_recipe() - remove the procmail block
sub remove_recipe
{
return if (!-r $procmailrc);
&lock_file($procmailrc);
my $lref = &read_file_lines($procmailrc);
&strip_recipe($lref);
&flush_file_lines($procmailrc);
&unlock_file($procmailrc);
}

sub strip_recipe
{
my ($lref) = @_;
my ($s, $e);
for (my $i = 0; $i < @$lref; $i++) {
	$s = $i if (!defined($s) && index($lref->[$i], $mark_begin) == 0);
	if (defined($s) && index($lref->[$i], $mark_end) == 0) { $e = $i; last; }
	}
splice(@$lref, $s, $e - $s + 1) if (defined($s) && defined($e));
}

# check_requirements() -> error message, or undef if OK
sub check_requirements
{
return $text{'check_procmail'} if (!&has_command("procmail"));
return $text{'check_postfix'} if (!-x "/usr/sbin/postconf");
eval "use Mail::DKIM::Verifier; 1" or return $text{'check_dkim'};
return undef;
}

# parse_addresses(text) -> list of addresses (one per line or comma)
sub parse_addresses
{
my ($str) = @_;
my %seen;
return grep { $_ ne '' && !$seen{lc $_}++ }
       map { s/^\s+|\s+$//gr } split(/[\r\n,]+/, $str // '');
}

# forward_kind(&user) -> ( has_local_copy, loop_risk, @external_addresses )
# for the mailbox's normal Virtualmin forwarding.
# Loop risk: Virtualmin writes "keep a local copy" as \<user> in the aliases
# file. When that local name contains "@" (user@domain style Unix users),
# Postfix's local(8) does not treat \user@domain as a local mailbox but as
# an address, which is mapped back to the same alias, so every message is
# forwarded again and again.
sub forward_kind
{
my ($user) = @_;
my @to = @{$user->{'to'} || []};
return (0, 0) if (!@to);
&foreign_require("virtual-server", "virtual-server-lib.pl");
my @self = grep { (&virtual_server::alias_type($_, $user->{'user'}))[0] == 10 } @to;
my $local = scalar(@self);
my @ext = grep { !/^[\\|\/:.%]/ && /\@([^\@\s]+)$/ && !&is_hosted_domain($1) } @to;
# The loop needs both: a local copy written as \name@domain, and more targets.
my $loop = @to > 1 && grep { /^\\\S*\@/ } @self;
$loop = $loop ? 1 : 0;
return ($local ? 1 : 0, $loop, @ext);
}

# is_hosted_domain(domain) -> 1 if Virtualmin hosts this domain
sub is_hosted_domain
{
my ($dname) = @_;
&foreign_require("virtual-server", "virtual-server-lib.pl");
$dname = lc($dname);
while ($dname =~ /\./) {
	return 1 if (&virtual_server::get_domain_by("dom", $dname));
	$dname =~ s/^[^.]+\.//;
	}
return 0;
}

1;

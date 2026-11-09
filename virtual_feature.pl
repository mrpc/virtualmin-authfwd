# virtual_feature.pl - Virtualmin plugin hooks for Authenticated Forwarding
# Adds a per-mailbox "Forward authenticated mail to" field.
# License: GPL-3.0-or-later
use strict;
use warnings;
our (%text, $module_name);

do 'authfwd-lib.pl';
my $input_name = $module_name;
$input_name =~ s/[^A-Za-z0-9]/_/g;
&load_theme_library();

# feature_name() - short name shown in Features and Plugins
sub feature_name
{
return $text{'feat_name'};
}

# feature_label(in-edit-form) - this plugin adds no per-domain feature
sub feature_label
{
return $text{'feat_name'};
}

# feature_check() - undef if the plugin can be used, or an error message
sub feature_check
{
return &check_requirements();
}

# feature_always_backup(&domain, file, ...) - save this domain's forwards
# into every domain backup (this plugin is not a per-domain feature).
sub feature_always_backup
{
my ($d, $file) = @_;
my %f = &domain_forwards($d);
my $fh = "BACKUP";
&open_tempfile($fh, ">$file");
foreach my $k (sort keys %f) {
	&print_tempfile($fh, join(" ", $k, @{$f{$k}}), "\n");
	}
&close_tempfile($fh);
return 1;
}

# feature_always_restore(&domain, file, ...) - put the forwards back
sub feature_always_restore
{
my ($d, $file) = @_;
my $lref = &read_file_lines($file, 1);
my $any = 0;
foreach my $l (@$lref) {
	my ($k, @t) = split(/\s+/, $l);
	next if (!defined($k) || !@t);
	&set_forwards($k, \@t);
	$any++;
	}
&unflush_file_lines($file);
&install_recipe() if ($any && !&recipe_installed());
return 1;
}

# feature_always_delete(&domain) - drop the forwards of a deleted domain
sub feature_always_delete
{
my ($d) = @_;
my %f = &domain_forwards($d);
&set_forwards($_, [ ]) foreach (keys %f);
return 1;
}

# feature_always_modify(&domain, &olddomain) - follow a domain rename
sub feature_always_modify
{
my ($d, $oldd) = @_;
return 1 if (!$oldd || lc($d->{'dom'}) eq lc($oldd->{'dom'}));
my ($o, $n) = ($oldd->{'dom'}, $d->{'dom'});
my %f = &list_forwards();
foreach my $k (keys %f) {
	next if ($k !~ /^([^\@]+)\@\Q$o\E$/i);
	&rename_forwards($k, "$1\@$n");
	}
return 1;
}

# mailbox_inputs(&user, new, &domain) - field on the Edit Mailbox page
sub mailbox_inputs
{
my ($user, $new, $dom) = @_;
return undef if (!$dom || !$dom->{'mail'});
my @t = $new ? () : &get_forwards($user->{'user'});
no warnings "once";
$main::ui_table_cols = 2;	# themes divide by this; not always set yet
use warnings "once";
my $warn = "";
if (!$new) {
	my ($local, $loop, @ext) = &forward_kind($user);
	$warn = "<br><b>".$text{'warn_loop'}."</b>" if ($loop);
	$warn .= "<br>".&text('warn_plain', &html_escape(join(", ", @ext)))
		if ($local && @ext && !$loop);
	}
return &ui_table_row(&hlink($text{'mail_targets'}, "targets"),
		     &ui_textarea($input_name, join("\n", @t), 3, 50).
		     "<br>".$text{'mail_targets_desc'}.$warn);
}

# mailbox_validate(&user, &olduser, &in, new, &domain) - error or undef
sub mailbox_validate
{
my ($user, $olduser, $in, $new, $dom) = @_;
return undef if (!$dom || !$dom->{'mail'});
my @t = &parse_addresses($in->{$input_name});
return undef if (!@t);
return $text{'check_failed'}.": ".&check_requirements()
	if (&check_requirements());
my %vfwd = map { lc($_), 1 } grep { !/^[\\|\/:.%]/ && /\@/ } @{$user->{'to'} || []};
foreach my $a (@t) {
	$a =~ /^[^\s\@]+\@([A-Za-z0-9.-]+\.[A-Za-z]{2,})$/ ||
		return &text('err_addr', &html_escape($a));
	&is_hosted_domain($1) &&
		return &text('err_local', &html_escape($a));
	$vfwd{lc($a)} &&
		return &text('err_dup', &html_escape($a));
	}
return undef;
}

# mailbox_save(&user, &olduser, &in, new, &domain)
sub mailbox_save
{
my ($user, $olduser, $in, $new, $dom) = @_;
return undef if (!$dom || !$dom->{'mail'});
return undef if (!defined($in->{$input_name}));
my @t = &parse_addresses($in->{$input_name});
if (!$new && $olduser && $olduser->{'user'} &&
    $olduser->{'user'} ne $user->{'user'}) {
	&set_forwards($olduser->{'user'}, [ ]);
	}
&set_forwards($user->{'user'}, \@t);
&install_recipe() if (@t && !&recipe_installed());
return @t ? 1 : 0;
}

# mailbox_modify(&user, &olduser, &domain) - called on renames etc.
sub mailbox_modify
{
my ($user, $olduser, $dom) = @_;
return if (!$olduser || !$olduser->{'user'});
&rename_forwards($olduser->{'user'}, $user->{'user'});
}

# mailbox_delete(&user, &domain)
sub mailbox_delete
{
my ($user, $dom) = @_;
&set_forwards($user->{'user'}, [ ]);
}

# mailbox_header(&domain) - column title in the mailbox list
sub mailbox_header
{
my ($dom) = @_;
return $dom && $dom->{'mail'} ? $text{'mail_header'} : undef;
}

# mailbox_column(&user, &domain) - column value in the mailbox list
sub mailbox_column
{
my ($user, $dom) = @_;
my @t = &get_forwards($user->{'user'});
my $col = @t ? &html_escape(join(", ", @t)) : "";
my (undef, $loop) = &forward_kind($user);
$col .= ($col ? " " : "")."<b>".$text{'col_loop'}."</b>" if ($loop);
return $col;
}

1;

#!/usr/bin/perl
# index.cgi - overview of authenticated forwarding on this server
use strict;
use warnings;
our (%text, %in, %config);

require './authfwd-lib.pl';
&ReadParse();
&foreign_require("virtual-server", "virtual-server-lib.pl");
my %access = &get_module_acl();
my $only = $in{'dom'} ? &virtual_server::get_domain($in{'dom'}) : undef;
&ui_print_header($only ? &html_escape($only->{'dom'}) : undef,
		 $text{'index_title'}, "", "intro", 1, 1);
if ($only) {
	print &text('index_dom_only', "<tt>".&html_escape($only->{'dom'})."</tt>"),
	      " ", &ui_link("index.cgi", $text{'index_dom_all'}), "<p>\n";
	}

my $err = &check_requirements();
print "<b>$text{'check_failed'}: $err</b><p>\n" if ($err);
print &ui_alert_box($text{'index_norecipe'}, 'warn')
	if (!$err && scalar(&list_forwards()) && !&recipe_installed());

# Map every mailbox to its domain; collect normal forwards worth moving.
my %f = $only ? &domain_forwards($only) : &list_forwards();
my (%owner, @cands);
my @doms = $only ? ( $only ) : &virtual_server::list_domains();
foreach my $d (sort { $a->{'dom'} cmp $b->{'dom'} } @doms) {
	next if (!$d->{'mail'});
	foreach my $u (&virtual_server::list_domain_users($d, 0, 0, 1, 1)) {
		foreach my $k (keys %f) {
			$owner{$k} ||= [ $d, $u ] if (&key_matches_user($k, $u));
			}
		my ($local, $loop, @ext) = &forward_kind($u);
		push(@cands, [ $d, $u, $loop, \@ext ]) if ($local && @ext);
		}
	}

sub mailbox_link
{
my ($d, $u) = @_;
return &ui_link("../virtual-server/edit_user.cgi?dom=".&urlize($d->{'id'}).
		"&user=".&urlize($u->{'user'}), &html_escape($u->{'user'}));
}

# 1. Configured forwards
print &ui_subheading($text{'index_forwards'});
if (%f) {
	print &ui_columns_start([ $text{'index_dom'}, $text{'index_mbox'},
				  $text{'index_targets'} ], 100);
	foreach my $k (sort keys %f) {
		my ($d, $u) = @{$owner{$k} || []};
		print &ui_columns_row([
			$d ? &html_escape($d->{'dom'}) : "<i>$text{'index_orphan'}</i>",
			$d ? &mailbox_link($d, $u) : &html_escape($k),
			&html_escape(join(", ", @{$f{$k}})) ]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}

# 2. Normal forwards that keep a local copy: candidates to move here
print &ui_subheading($text{'index_cands'});
if (@cands) {
	print $text{'index_cands_desc'}, "<p>\n";
	print &ui_columns_start([ $text{'index_dom'}, $text{'index_mbox'},
				  $text{'index_targets'}, $text{'index_risk'},
				  $access{'migrate'} ? ( "" ) : ( ) ], 100);
	foreach my $c (@cands) {
		my ($d, $u, $loop, $ext) = @$c;
		print &ui_columns_row([
			&html_escape($d->{'dom'}),
			&mailbox_link($d, $u),
			&html_escape(join(", ", @$ext)),
			$loop ? "<b>$text{'index_loop'}</b>" : $text{'index_spam'},
			$access{'migrate'} ? (
			  &ui_form_start("migrate.cgi", "post").
			  &ui_hidden("dom", $d->{'id'}).
			  &ui_hidden("user", $u->{'user'}).
			  &ui_hidden("back", $only ? $only->{'id'} : "").
			  &ui_submit($text{'index_move'}).
			  &ui_form_end() ) : ( ) ]);
		}
	print &ui_columns_end();
	}
else {
	print "$text{'index_nocands'}<p>\n";
	}

# 3. What happened in the last 24 hours
my $hours = $config{'stats_hours'} && $config{'stats_hours'} =~ /^\d+$/ ?
		$config{'stats_hours'} : 24;
print &ui_subheading(&text('index_stats', $hours));
my $jc = &has_command("journalctl");
if ($jc) {
	my $out = &backquote_command("$jc -t authfwd --since -${hours}h -o cat --no-pager 2>/dev/null");
	my (%n, %skipdom);
	foreach my $l (split(/\n/, $out)) {
		$n{$1}++ if ($l =~ /^(FWD|SKIP|FAIL) /);
		$skipdom{lc $1}++ if ($l =~ /^SKIP .*from=<[^>]*\@([^>]+)>/);
		}
	print &ui_table_start(undef, undef, 2);
	print &ui_table_row($text{'index_nfwd'}, $n{'FWD'} || 0);
	print &ui_table_row($text{'index_nskip'}, $n{'SKIP'} || 0);
	print &ui_table_row($text{'index_nfail'}, $n{'FAIL'} ? "<b>$n{'FAIL'}</b>" : 0);
	my @top = (sort { $skipdom{$b} <=> $skipdom{$a} } keys %skipdom)[0..9];
	print &ui_table_row($text{'index_topskip'},
		join("<br>", map { &html_escape($_)." ($skipdom{$_})" } grep { defined } @top) || "-");
	print &ui_table_end();
	print "<p>", $text{'index_logs'}, "\n";
	}
else {
	print $text{'index_nojournal'}, "<p>\n";
	}

# Related tool by the same author: its page when installed, else where to get it
if (&foreign_available("openxs")) {
	print "<p>$text{'index_seealso'}: ",
	      &ui_link("../openxs/mail_accounts.cgi", $text{'index_openxs'}), "\n";
	}
elsif (!&foreign_installed("openxs")) {
	print "<p>$text{'index_seealso'}: ",
	      &ui_link("https://github.com/mrpc/OpenXS", "OpenXS", undef,
		       "target=_blank rel=noopener"),
	      " - $text{'index_openxs_get'}\n";
	}

&ui_print_footer("/", $text{'index'});

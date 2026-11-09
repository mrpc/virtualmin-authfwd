#!/usr/bin/perl
# migrate.cgi - move one mailbox's normal forward to authenticated forwarding
use strict;
use warnings;
our (%text, %in);

require './authfwd-lib.pl';
&error_setup($text{'mig_err'});
&ReadParse();
$ENV{'REQUEST_METHOD'} eq 'POST' || &error($text{'mig_epost'});
my %access = &get_module_acl();
$access{'migrate'} || &error($text{'mig_eacl'});
&foreign_require("virtual-server", "virtual-server-lib.pl");

my $d = &virtual_server::get_domain($in{'dom'});
$d || &error($text{'mig_edom'});
my ($u) = grep { $_->{'user'} eq $in{'user'} }
	       &virtual_server::list_domain_users($d, 0, 0, 1, 1);
$u || &error($text{'mig_euser'});

my $err = &migrate_mailbox($d, $u);
&error(&html_escape($err)) if ($err);
&webmin_log("migrate", "mailbox", $u->{'user'}, { 'dom' => $d->{'dom'} });
&redirect($in{'back'} ? "index.cgi?dom=".&urlize($in{'back'}) : "");

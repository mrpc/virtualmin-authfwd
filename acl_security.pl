# acl_security.pl - per Webmin user access options for this module
use strict;
use warnings;
our %text;

do 'authfwd-lib.pl';

# acl_security_form(&options)
sub acl_security_form
{
my ($o) = @_;
no warnings "once";
$main::ui_table_cols ||= 2;
use warnings "once";
print &ui_table_row($text{'acl_migrate'},
	&ui_yesno_radio("migrate", $o->{'migrate'} ? 1 : 0));
}

# acl_security_save(&options, &in)
sub acl_security_save
{
my ($o, $in) = @_;
$o->{'migrate'} = $in->{'migrate'} ? 1 : 0;
}

1;

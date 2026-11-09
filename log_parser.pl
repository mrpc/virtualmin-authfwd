# log_parser.pl - human-readable Webmin Actions Log entries for this module
use strict;
use warnings;
our %text;

do 'authfwd-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq "mailbox") {
	return &text('log_'.$action.'_mailbox',
		     "<tt>".&html_escape($object)."</tt>",
		     "<tt>".&html_escape($p->{'dom'} || '')."</tt>");
	}
return undef;
}

1;

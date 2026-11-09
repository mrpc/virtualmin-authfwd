# uninstall.pl - remove the procmail recipe; the forwards file is kept
use strict;
use warnings;
do 'authfwd-lib.pl';

sub module_uninstall
{
&remove_recipe();
}

1;

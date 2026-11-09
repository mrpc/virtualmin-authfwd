# postinstall.pl - refresh the procmail recipe after an upgrade
use strict;
use warnings;
do 'authfwd-lib.pl';

sub module_install
{
my %f = &list_forwards();
&install_recipe() if (%f || &recipe_installed());
}

1;

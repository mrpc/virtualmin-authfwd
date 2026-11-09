# Stub so that `perl -c` can check files that `use WebminCore` outside a
# real Webmin install (CI only). Webmin functions are called with & at
# run time, so compilation does not need them.
package WebminCore;
sub import { }
1;

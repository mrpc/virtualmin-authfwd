## What does this change

## Why

## How was this tested
- [ ] `make test` passes
- [ ] If this touches a `.cgi` or `*.pl` file: installed with `make dist` on a test Virtualmin server and checked in the browser, not just `perl -c`
- [ ] If this touches mail handling: a real message went through a forwarding mailbox and `journalctl -t authfwd` shows the expected decision
- [ ] `CHANGELOG` updated, if the change is visible to users

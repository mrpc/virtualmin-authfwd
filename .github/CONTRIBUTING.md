# Contributing

## Running the tests

```
make test
```

Needs Perl with `Mail::DKIM` (Debian/Ubuntu: `apt install libmail-dkim-perl`).
The tests run the forwarding decision script in dry-run mode against
synthetic messages. No mail is sent and no Webmin is needed.

## Testing a Webmin or Virtualmin change

The `.cgi` and `*.pl` files (other than `authfwd`) load `WebminCore` and the
Virtualmin library, which only exist inside a real Webmin install. CI only
syntax-checks them against a stub. Before changing them:

1. `make dist` and install the `.wbm.gz` on a test Virtualmin server
   (Webmin → Webmin Configuration → Webmin Modules).
2. Open the changed page in a browser, or save a mailbox, and check the real
   result, not just `perl -c`. Theme-related problems (for example a missing
   `ui_table_cols`) only show up in the real UI.
3. For a change to mail handling, send a real message through a forwarding
   mailbox and check `journalctl -t authfwd`.

## Pull requests

- Keep the diff focused: one change per PR.
- Add or update a test in `t/` for anything with real logic (a decision rule,
  a parser, name matching). A wording change does not need one.
- Add a line to `CHANGELOG` for user-visible changes.
- See the PR template for what to check before marking it ready.

## Reporting a vulnerability

Do not open a PR or public issue for a security vulnerability. See
[SECURITY.md](SECURITY.md).

# virtualmin-authfwd

A small Virtualmin plugin that forwards a copy of a mailbox's mail to external
addresses **without forwarding spam that the receiver would reject anyway**.

## The problem

A Virtualmin mailbox that keeps a local copy and forwards to Gmail, Outlook or
Yahoo sends every message on with its original envelope sender. The receiver
checks SPF against *your* server, which fails, so the message is accepted only
if it carries a valid DKIM signature. Spam usually has none, and Gmail rejects
it:

```
550-5.7.26 Your email has been blocked because the sender is unauthenticated.
550-5.7.26 Gmail requires all senders to authenticate with either SPF or DKIM.
```

These rejections pile up against your server's IP reputation. They can also
lead to rate limiting of the recipient (`450 4.2.1`). The usual fix, SRS,
makes the receiver *accept* that spam in your name. Spam-score filtering
(SpamAssassin) can drop legitimate mail.

## What this plugin does

It adds a **"Forward authenticated mail to"** field to the Edit Mailbox page,
plus a column in the mailbox list. For each delivered message:

| Message | Forwarded? |
|---|---|
| External sender with a passing DKIM signature | yes |
| Sender in a domain hosted on this server (contact forms, local users) | yes |
| Bounce (null sender) | yes |
| DKIM check failed temporarily (DNS error) | yes |
| External sender without a passing DKIM signature | **no**: the receiver would reject it |

The local mailbox **always** gets every message. Only the forwarded copy is
held back, and only in cases where it would bounce. Nothing is scored and
nothing is deleted.

Each decision goes to syslog with the tag `authfwd`:

```
journalctl -t authfwd
```

## It also avoids the "keep a local copy" mail loop

When a Virtualmin mailbox forwards with **keep a local copy**, Virtualmin
writes the local copy into the aliases file as `\<unix user>`. If that Unix
user name contains `@` (user@domain style mailboxes), Postfix does not treat
it as a local mailbox. It treats it as an address, which maps back to the same
alias, and every message is forwarded again and again, often dozens of times
to the external recipient.

With this plugin the mailbox stays a plain mailbox with only local delivery,
and the plugin sends the copy itself, never to a domain hosted on the server.
The plugin also:

- shows a warning on the Edit Mailbox page, and marks the mailbox list
  column, when the normal forwarding of a mailbox has this loop risk;
- flags such mailboxes as `MAIL LOOP RISK` in `migrate-forwards.pl`, which
  moves them over.

## Requirements

- Virtualmin 7 or later, with **Postfix** and **procmail** (the Virtualmin default)
- Perl `Mail::DKIM`: `apt install libmail-dkim-perl` or `dnf install perl-Mail-DKIM`

## Install

1. Download `virtualmin-authfwd-<version>.wbm.gz` from the releases page, or
   build it with `make dist`.
2. Webmin → Webmin Configuration → Webmin Modules → install from file.
3. Virtualmin → System Settings → Features and Plugins → enable
   **Authenticated forwarding**.
4. Open a mailbox, enter one address per line under "Forward authenticated
   mail to", and save.

On first use the plugin adds a small block to the top of `/etc/procmailrc`,
between `# BEGIN virtualmin-authfwd` and `# END virtualmin-authfwd`.
Uninstalling the module removes that block.

## Overview page

Webmin → Servers → **Authenticated Forwarding** shows:

- every configured authenticated forward, with a link to its mailbox;
- mailboxes whose *normal* forwarding keeps a local copy and sends to an
  external address, marked "Mail loop" or "Forwards spam", each with a
  **Move to authenticated forwarding** button;
- the last 24 hours: messages forwarded, not forwarded and failed, plus the
  top sender domains that were not forwarded.

## Backups

The forwards of a virtual server are included in its Virtualmin backups and
come back on restore. They also follow a domain rename, and they are removed
when the domain is deleted.

## Moving existing forwards

Mailboxes that already have "local copy + forward to external address" can be
moved from the overview page, or all at once from the command line:

```
cd /usr/share/webmin/virtualmin-authfwd   # /usr/libexec/webmin/... on RHEL
./migrate-forwards.pl                 # list what would change
./migrate-forwards.pl --apply         # move them
./migrate-forwards.pl --domain example.com --apply
```

Mailboxes that only forward, with no local copy, are left alone. The plugin
needs a local delivery to hook into.

## Notes

- Do not also list the same address as a normal Virtualmin forward. The
  plugin refuses to save that, because the recipient would get every message
  twice.
- Addresses in domains hosted on the same server are refused. Use a normal
  forward for those.
- Forwards are stored in `/etc/authfwd/forwards`, one line per mailbox:
  `<unix user> <address> ...`.

## Testing

```
make test     # needs perl with Mail::DKIM
```

## License

GPL-3.0-or-later. See `LICENSE`.

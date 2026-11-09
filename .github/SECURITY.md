# Security Policy

The forwarding script runs as root from `/etc/procmailrc` and reads every
message delivered to a forwarding mailbox. Please report vulnerabilities
privately, not through a public issue.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting:
[**Report a vulnerability**](https://github.com/mrpc/virtualmin-authfwd/security/advisories/new)
(Security tab → Report a vulnerability). This opens a private advisory that
only the maintainers can see until a fix is ready.

Please include:
- the affected file or component (for example `authfwd`, the Edit Mailbox
  field, the overview page);
- steps to reproduce, or a minimal proof of concept;
- the impact as you see it (for example mail sent to an unintended address,
  privilege escalation, information disclosure).

## Supported versions

Only the latest release receives security fixes.

## Response

This is a single-maintainer project. There is no guaranteed response time,
but reports are read as soon as possible and a real vulnerability takes
priority over other work.

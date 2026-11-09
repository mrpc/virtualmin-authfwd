#!/bin/sh
# Self-check for the authfwd decision logic (dry run, no mail is sent).
# Needs perl with Mail::DKIM. Run: sh t/test-authfwd.sh
set -u
dir=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

cat > "$tmp/forwards" <<'EOF'
# test config
box@example.org someone@example.net loop@example.org
EOF

msg() {  # $1 = Return-Path, $2 = extra header line
    printf 'From x  Mon Jan  1 00:00:00 2026\nReturn-Path: <%s>\n%bFrom: a <%s>\nTo: box@example.org\nSubject: t\nMessage-ID: <t@test>\n\nbody\n' "$1" "$2" "$1"
}

check() {  # $1 = name, $2 = expected prefix, $3 = LOGNAME, stdin = message
    out=$(AUTHFWD_CONF="$tmp/forwards" AUTHFWD_DRYRUN=1 \
          AUTHFWD_LOCAL_DOMAINS="example.org" LOGNAME="$3" \
          perl "$dir/authfwd")
    if [ -z "$2" ]; then
        [ -z "$out" ] && echo "ok   $1" || { echo "FAIL $1: expected no output, got '$out'"; fail=1; }
        return
    fi
    case "$out" in
        "$2"*) echo "ok   $1" ;;
        *) echo "FAIL $1: expected '$2', got '$out'"; fail=1 ;;
    esac
}

msg "spammer@spam.invalid" "" | check "external sender, no DKIM -> skip" "SKIP" box@example.org
msg "" "" | check "null sender (bounce) -> forward" "FWD from=<> reason=null sender" box@example.org
msg "form@www.example.org" "" | check "hosted subdomain sender -> forward" "FWD from=<form@www.example.org> reason=local domain" box@example.org
msg "x@other.invalid" "DKIM-Signature: v=1; a=rsa-sha256; d=other.invalid; s=s; h=from; bh=AAAA; b=AAAA\n" | \
    check "external sender, invalid DKIM -> skip" "SKIP" box@example.org
msg "spammer@spam.invalid" "" | check "mailbox without forwards -> nothing" "" nobody@example.org

# The loop guard drops the hosted target; with only hosted targets nothing happens.
printf 'only@example.org loop@example.org\n' > "$tmp/forwards"
msg "" "" | check "only hosted targets -> nothing (loop guard)" "" only@example.org

exit $fail

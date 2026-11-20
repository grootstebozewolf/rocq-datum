#!/usr/bin/env bash
# Self-test for the audit gates.
#
# Each directory under cases/ holds:
#   Fixture.v           installed as theories/Fixture.v (Datum.Fixture)
#   ledger.src          replaces audit/ledger.src
#   exceptions.tsv      optional; replaces audit/exceptions.tsv
#   base_counts.tsv     optional; baseline for the ratchet step
#   expect              pass | fail-emit | fail-compile | fail-report | fail-ratchet
#   expect.ledger.tsv   optional; exact expected audit/ledger.tsv
#
# The case runs in a scratch copy of the repository and the first failing
# step is compared against `expect`.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
ok=0
bad=0

for case in "$here"/cases/*/; do
  name=$(basename "$case")
  expect=$(cat "$case/expect")
  tmp=$(mktemp -d)
  cp -r "$root/theories" "$root/audit" "$root/_CoqProject" "$root/Makefile" "$tmp/"
  rm -rf "$tmp/audit/_out"
  cp "$case/Fixture.v" "$tmp/theories/Fixture.v"
  echo "theories/Fixture.v" >> "$tmp/_CoqProject"
  cp "$case/ledger.src" "$tmp/audit/ledger.src"
  if [ -f "$case/exceptions.tsv" ]; then
    cp "$case/exceptions.tsv" "$tmp/audit/exceptions.tsv"
  fi

  got=pass
  log="$tmp/test.log"
  run() { (cd "$tmp" && "$@") >>"$log" 2>&1; }
  run make -s all || got=fail-build
  [ "$got" = pass ] && { run python3 audit/ledger.py emit || got=fail-emit; }
  [ "$got" = pass ] && { run mkdir -p audit/_out; run rocq compile -R theories Datum -Q audit DatumAudit audit/Ledger.v || got=fail-compile; }
  [ "$got" = pass ] && { run python3 audit/ledger.py report || got=fail-report; }
  if [ "$got" = pass ] && [ -f "$case/base_counts.tsv" ]; then
    run python3 audit/ledger.py ratchet "$case/base_counts.tsv" || got=fail-ratchet
  fi
  if [ "$got" = pass ] && [ -f "$case/expect.ledger.tsv" ]; then
    if ! diff -u "$case/expect.ledger.tsv" "$tmp/audit/ledger.tsv" >>"$log"; then
      got=wrong-ledger
    fi
  fi

  if [ "$got" = "$expect" ]; then
    echo "ok    $name ($got)"
    ok=$((ok + 1))
  else
    echo "FAIL  $name: expected $expect, got $got"
    sed 's/^/      | /' "$log"
    bad=$((bad + 1))
  fi
  rm -rf "$tmp"
done

echo "ledger self-test: $ok ok, $bad failed"
[ "$bad" -eq 0 ]

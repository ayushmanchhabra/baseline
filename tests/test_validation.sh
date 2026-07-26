#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf '[1/2] Checking CLI help output... '
if ! ./main.sh --help >"$tmp_dir/help.txt" 2>&1; then
  echo "failed"
  cat "$tmp_dir/help.txt"
  exit 1
fi
if ! grep -q 'Usage:' "$tmp_dir/help.txt"; then
  echo "failed"
  cat "$tmp_dir/help.txt"
  exit 1
fi
echo "passed"

printf '[2/3] Checking malformed-domain validation... '
if ./main.sh 'bad domain' "$tmp_dir/output" >"$tmp_dir/invalid.log" 2>&1; then
  echo "failed"
  exit 1
fi
if ! grep -q 'Invalid target' "$tmp_dir/invalid.log"; then
  echo "failed"
  cat "$tmp_dir/invalid.log"
  exit 1
fi
echo "passed"

printf '[3/3] Checking valid-domain acceptance... '
if ! ./main.sh 'example.com' "$tmp_dir/output" >"$tmp_dir/valid.log" 2>&1; then
  echo "failed"
  cat "$tmp_dir/valid.log"
  exit 1
fi
if ! grep -q 'Results written' "$tmp_dir/valid.log"; then
  echo "failed"
  cat "$tmp_dir/valid.log"
  exit 1
fi
echo "passed"

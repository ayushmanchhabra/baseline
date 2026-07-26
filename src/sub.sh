#!/usr/bin/env bash
#
# sub.sh - Discover subdomains for a target domain using subfinder.
#
# Purpose:
#   Runs subfinder against a hostname and writes a unique list of discovered
#   subdomains to a text file.
#
# Usage:
#   ./sub.sh <domain> <output.txt>
#
# Examples:
#   ./sub.sh example.com ./subdomains.txt
#   ./sub.sh api.example.com ./out/subdomains.txt
#
# Notes:
#   - The input must be a valid hostname, not a URL or a string containing spaces.
#   - The output file is written atomically and will be overwritten safely.
#

set -euo pipefail

usage() {
  echo "Usage: $0 <domain> <output.txt>" >&2
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_domain() {
  local value="${1,,}"
  value="${value%.}"

  [[ -n "$value" ]] || return 1
  [[ "$value" != *" "* ]] || return 1
  [[ "$value" != http://* && "$value" != https://* ]] || return 1
  [[ "$value" != */* ]] || return 1
  [[ "$value" != *:* ]] || return 1
  [[ "$value" =~ ^([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])+$ ]] || return 1
}

[[ $# -eq 2 ]] || { usage; exit 1; }

target="${1}"
output_file="${2}"

[[ -n "$target" ]] || die "Target domain cannot be empty"
[[ "$output_file" == *.txt ]] || die "Output file must have a .txt extension"

validate_domain "$target" || die "Invalid target '$target'. Provide a hostname such as example.com"

output_dir="$(dirname -- "$output_file")"
mkdir -p -- "$output_dir" || die "Unable to create output directory: $output_dir"

require_cmd subfinder

tmp_output="$(mktemp "${TMPDIR:-/tmp}/subdomains.XXXXXX")"
tmp_error="$(mktemp "${TMPDIR:-/tmp}/subfinder.XXXXXX")"
trap 'rm -f -- "$tmp_output" "$tmp_error"' EXIT

if ! subfinder -d "$target" -all -silent >"$tmp_output" 2>"$tmp_error"; then
  cat "$tmp_error" >&2
  die "subfinder failed for target '$target'"
fi

if [ -s "$tmp_output" ]; then
  sed 's/^www\.//' "$tmp_output" | sort -u >"${tmp_output}.sorted"
else
  : >"${tmp_output}.sorted"
fi

mv "${tmp_output}.sorted" "$output_file"
echo "Subdomains written to $output_file"

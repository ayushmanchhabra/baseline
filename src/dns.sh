#!/usr/bin/env bash
#
# dns.sh - Query common DNS record types for a host or list of hosts.
#
# Purpose:
#   Accepts either a single hostname or a file containing multiple hostnames and
#   records the results of common DNS queries into a CSV file.
#
# Usage:
#   ./dns.sh <url|subdomains.txt> <output.csv>
#
# Examples:
#   ./dns.sh example.com ./dns_records.csv
#   ./dns.sh ./subdomains.txt ./out/dns_records.csv
#
# Notes:
#   - The script checks for malformed hosts and skips invalid entries gracefully.
#   - Supported record types include A, AAAA, CNAME, MX, TXT, NS, and SOA.
#

set -euo pipefail

usage() {
  echo "Usage: $0 <url|subdomains.txt> <output.csv>" >&2
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

clean_uri() {
  local value="${1,,}"
  value="${value#*://}"
  value="${value%%/*}"
  value="${value%%\?*}"
  value="${value%%#*}"
  value="${value%:}"
  value="${value#www.}"
  echo "$value"
}

validate_host() {
  local value="${1,,}"
  value="${value%.}"

  [[ -n "$value" ]] || return 1
  [[ "$value" != *" "* ]] || return 1
  [[ "$value" != http://* && "$value" != https://* ]] || return 1
  [[ "$value" != */* ]] || return 1
  [[ "$value" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])+$ ]] || [[ "$value" == "localhost" ]]
}

load_inputs() {
  local input_path="$1"
  if [[ "$input_path" == *.txt || "$input_path" == *.csv || "$input_path" == *.list || "$input_path" == */* ]]; then
    [[ -f "$input_path" ]] || die "File not found: $input_path"
    mapfile -t uris < <(sed '/^[[:space:]]*$/d; s/^[[:space:]]*//; s/[[:space:]]*$//' "$input_path")
    [[ ${#uris[@]} -gt 0 ]] || die "No URIs found in $input_path"
  else
    uris=("$input_path")
  fi
}

[[ $# -eq 2 ]] || { usage; exit 1; }

input_path="${1}"
output_file="${2}"

[[ -n "$input_path" ]] || die "Input path cannot be empty"
[[ "$output_file" == *.csv ]] || die "Output file must have a .csv extension"

require_cmd dig

output_dir="$(dirname -- "$output_file")"
mkdir -p -- "$output_dir" || die "Unable to create output directory: $output_dir"

declare -a uris=()
load_inputs "$input_path"

tmp_output="$(mktemp "${TMPDIR:-/tmp}/dns.XXXXXX")"
trap 'rm -f -- "$tmp_output"' EXIT

{
  echo "URI,TTL,DNS Record,DNS Value"
  for raw_uri in "${uris[@]}"; do
    uri="$(clean_uri "$raw_uri")"
    if ! validate_host "$uri"; then
      echo "$uri,N/A,ERROR,invalid target"
      continue
    fi

    for rtype in A AAAA CNAME MX TXT NS SOA; do
      if dig_output=$(dig +time=3 +tries=1 +noall +answer "$rtype" "$uri" 2>/dev/null); then
        while IFS= read -r line; do
          [ -n "$line" ] || continue
          read -r _ ttl _ rtype_col val <<< "$line"
          if [ -n "$val" ]; then
            case "$val" in
              *,*) echo "$uri,$ttl,$rtype_col,\"$val\"" ;;
              *)   echo "$uri,$ttl,$rtype_col,$val" ;;
            esac
          fi
        done <<< "$dig_output"
      fi
    done
  done
} > "$tmp_output"

{
  head -n 1 "$tmp_output"
  tail -n +2 "$tmp_output" | sort -u
} > "$output_file"

echo "DNS results written to $output_file"

#!/usr/bin/env bash
#
# main.sh - Orchestrate subdomain, DNS, and certificate collection for a target domain.
#
# Purpose:
#   Runs the subdomain discovery, DNS lookup, and certificate inspection scripts
#   against a single target domain and writes the results to an output directory.
#
# Usage:
#   ./main.sh <domain> <output_dir>
#
# Examples:
#   ./main.sh example.com ./out
#   ./main.sh api.example.com ./reports
#
# Notes:
#   - The target must be a single hostname such as example.com or api.example.com.
#   - The output directory is created automatically if it does not exist.
#   - The script validates the input and fails fast on malformed targets.
#

set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: ./main.sh <domain> <output_dir>

Examples:
  ./main.sh example.com ./out
  ./main.sh api.example.com ./reports

The target must be a single hostname such as example.com or api.example.com.
EOF
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

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

[[ $# -eq 2 ]] || { usage; exit 1; }

input_target="${1}"
output_dir="${2}"

[[ -n "$input_target" ]] || die "Target domain cannot be empty"
[[ -n "$output_dir" ]] || die "Output directory cannot be empty"

validate_domain "$input_target" || die "Invalid target '$input_target'. Provide a hostname such as example.com"

if [[ -e "$output_dir" && ! -d "$output_dir" ]]; then
  die "Output path exists but is not a directory: $output_dir"
fi

mkdir -p -- "$output_dir" || die "Unable to create output directory: $output_dir"
[[ -w "$output_dir" ]] || die "Output directory is not writable: $output_dir"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

require_cmd subfinder
require_cmd dig
require_cmd openssl

input_target="${input_target%.}"
input_target="${input_target,,}"

"$script_dir/src/sub.sh" "$input_target" "$output_dir/subdomains.txt"
"$script_dir/src/dns.sh" "$output_dir/subdomains.txt" "$output_dir/dns_records.csv"
"$script_dir/src/crt.sh" "$output_dir/subdomains.txt" "$output_dir/tls_certificates.csv"

echo "Results written to $output_dir"

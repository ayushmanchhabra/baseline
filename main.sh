#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <domain|target> <output_dir>" >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 1
fi

input_target="${1}"
output_dir="${2}"

if [ -z "$input_target" ] || [ -z "$output_dir" ]; then
  usage
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p -- "$output_dir"

"$script_dir/src/sub.sh" "$input_target" "$output_dir/subdomains.txt"
"$script_dir/src/dns.sh" "$output_dir/subdomains.txt" "$output_dir/dns_records.csv"
"$script_dir/src/crt.sh" "$output_dir/subdomains.txt" "$output_dir/tls_certificates.csv"

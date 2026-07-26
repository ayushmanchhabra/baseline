#!/usr/bin/env bash
#
# crt.sh - Retrieve TLS certificate details for hosts and export them to CSV.
#
# Purpose:
#   Accepts either a single host or a file of hosts and collects certificate
#   subject, issuer, validity dates, and days until expiry into a CSV report.
#
# Usage:
#   ./crt.sh <url|subdomains.txt> <output.csv>
#
# Examples:
#   ./crt.sh example.com ./tls_certificates.csv
#   ./crt.sh ./subdomains.txt ./out/tls_certificates.csv
#
# Notes:
#   - The script validates hostnames before attempting TLS connections.
#   - Set SHORT=1 to reduce subject and issuer values to the CN component only.
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

sanitize() {
  echo "$1" | sed 's/,/;/g' | sed 's/"/'"'"'/g' | tr -s ' ' | sed 's/^ *//; s/ *$//'
}

cn_only() {
  local cn
  cn=$(echo "$1" | grep -oP 'CN\s*=\s*\K[^,/]+' | head -1)
  if [ -n "$cn" ]; then
    echo "$cn"
  else
    echo "$1"
  fi
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

require_cmd openssl

output_dir="$(dirname -- "$output_file")"
mkdir -p -- "$output_dir" || die "Unable to create output directory: $output_dir"

declare -a uris=()
load_inputs "$input_path"

tmp_output="$(mktemp "${TMPDIR:-/tmp}/certs.XXXXXX")"
trap 'rm -f -- "$tmp_output"' EXIT

{
  echo "URI,Cert Subject,Cert Issuer,Not Before,Not After,Days Until Expiry"

  for raw_uri in "${uris[@]}"; do
    uri="$(clean_uri "$raw_uri")"
    if ! validate_host "$uri"; then
      echo "$uri,N/A,N/A,N/A,N/A,N/A"
      continue
    fi

    if ! cert_output=$(echo | openssl s_client -connect "${uri}:443" -servername "$uri" -timeout 5 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null); then
      echo "$uri,N/A,N/A,N/A,N/A,N/A"
      continue
    fi

    subject=$(echo "$cert_output" | grep '^subject=' | sed 's/^subject=//')
    issuer=$(echo "$cert_output" | grep '^issuer=' | sed 's/^issuer=//')
    not_before=$(echo "$cert_output" | grep '^notBefore=' | sed 's/^notBefore=//')
    not_after=$(echo "$cert_output" | grep '^notAfter=' | sed 's/^notAfter=//')

    if [ "${SHORT:-0}" = "1" ]; then
      subject=$(cn_only "$subject")
      issuer=$(cn_only "$issuer")
    fi

    subject=$(sanitize "$subject")
    issuer=$(sanitize "$issuer")
    not_before=$(sanitize "$not_before")
    not_after=$(sanitize "$not_after")

    if [ -n "$not_after" ]; then
      expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || true)
      now_epoch=$(date +%s)
      if [ -n "$expiry_epoch" ]; then
        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
      else
        days_left="N/A"
      fi
    else
      days_left="N/A"
    fi

    echo "$uri,$subject,$issuer,$not_before,$not_after,$days_left"
  done
} > "$tmp_output"

{
  head -n 1 "$tmp_output"
  tail -n +2 "$tmp_output" | sort -u
} > "$output_file"

echo "Certificate info written to $output_file"

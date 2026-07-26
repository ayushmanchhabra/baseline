#!/usr/bin/env bash
#
# 403.sh - Test common HTTP methods and headers against a target URL.
#
# Purpose:
#   Sends a series of method-based and header-based requests to a URL and writes
#   the observed status codes and response sizes to a CSV file.
#
# Usage:
#   ./403.sh -h <URL> -o <output.csv>
#
# Examples:
#   ./403.sh -h https://example.com -o ./http_methods.csv
#   ./403.sh -h https://api.example.com -o ./out/methods.csv
#
# Notes:
#   - The target must be a valid HTTP or HTTPS URL.
#   - The script uses conservative timeouts to avoid hanging on slow targets.
#

set -euo pipefail

usage() {
    echo "Usage: $0 -h <URL> -o <output.csv>" >&2
}

die() {
    echo "Error: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_url() {
    local value="$1"
    [[ -n "$value" ]] || return 1
    [[ "$value" != *" "* ]] || return 1
    [[ "$value" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]] || return 1
}

url=""
outfile=""

while getopts ":h:o:" opt; do
    case "$opt" in
        h) url="$OPTARG" ;;
        o) outfile="$OPTARG" ;;
        \?) echo "Error: invalid option -$OPTARG" >&2; usage; exit 1 ;;
        :) echo "Error: option -$OPTARG requires an argument" >&2; usage; exit 1 ;;
    esac
done

[[ -n "$url" ]] || die "URL (-h) is required"
[[ -n "$outfile" ]] || die "Output file (-o) is required"
[[ "$outfile" == *.csv ]] || die "Output file must have a .csv extension"
validate_url "$url" || die "Invalid URL '$url'"

require_cmd curl

output_dir="$(dirname -- "$outfile")"
mkdir -p -- "$output_dir" || die "Unable to create output directory: $output_dir"

tmp_output="$(mktemp "${TMPDIR:-/tmp}/http-methods.XXXXXX")"
trap 'rm -f -- "$tmp_output"' EXIT

echo "URL,Category,Payload,Status Code,Size" > "$tmp_output"

http_methods=(
    "GET"
    "HEAD"
    "POST"
    "PUT"
    "DELETE"
    "CONNECT"
    "OPTIONS"
    "TRACE"
    "PATCH"
    "INVENTED"
    "HACK"
)

http_headers=(
    "X-Originating-IP: 127.0.0.1"
    "X-Forwarded-For: 127.0.0.1"
    "X-Forwarded: 127.0.0.1"
    "Forwarded-For: 127.0.0.1"
    "X-Remote-IP: 127.0.0.1"
    "X-Remote-Addr: 127.0.0.1"
    "X-ProxyUser-Ip: 127.0.0.1"
    "X-Original-URL: 127.0.0.1"
    "Client-IP: 127.0.0.1"
    "True-Client-IP: 127.0.0.1"
    "Cluster-Client-IP: 127.0.0.1"
    "Host: localhost"
)

total=$(( ${#http_methods[@]} + ${#http_headers[@]} ))
count=0

echo "[*] Target: $url" >&2
echo "[*] Total checks: $total" >&2
echo >&2

echo "[*] Testing HTTP methods (${#http_methods[@]})..." >&2
for method in "${http_methods[@]}"; do
    count=$((count + 1))
    printf "  [%d/%d] Method: %-10s" "$count" "$total" "$method" >&2
    result=$(curl --connect-timeout 5 --max-time 10 -k -s -o /dev/null -L -w "%{http_code},%{size_download}" -X "$method" "$url" 2>/dev/null || true)
    echo " -> $result" >&2
    echo "$url,Method,$method,$result" >> "$tmp_output"
done

echo >&2
echo "[*] Testing headers (${#http_headers[@]})..." >&2
for header in "${http_headers[@]}"; do
    count=$((count + 1))
    printf "  [%d/%d] Header: %-40s" "$count" "$total" "$header" >&2
    result=$(curl --connect-timeout 5 --max-time 10 -k -s -o /dev/null -L -w "%{http_code},%{size_download}" -H "$header" "$url" 2>/dev/null || true)
    echo " -> $result" >&2
    echo "$url,Header,$header,$result" >> "$tmp_output"
done

mv "$tmp_output" "$outfile"
echo "[*] Done. Results saved to $outfile" >&2

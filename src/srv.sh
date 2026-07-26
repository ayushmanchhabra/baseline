#!/usr/bin/env bash
#
# srv.sh - Look up the well-known service name for TCP port(s).
#
# Purpose:
#   Tests one or more TCP ports on a raw IPv4 address and reports the matching
#   service name (when available) alongside the port result.
#
# Usage:
#   ./srv.sh -h <ip> -p <ports> -o <output.csv> -t <timeout_seconds>
#
# Examples:
#   ./srv.sh -h 8.8.8.8 -p 443 -o output.csv -t 0.5
#   ./srv.sh -h 8.8.8.8 -p 80,443,445 -o ./out/services.csv -t 1
#
# Notes:
#   - -h must be a raw IPv4 address; hostnames are not resolved.
#   - -p accepts a range (1-65535), a list (80,443,445), or a single port (22).
#   - For each port, the script first attempts a TCP connection within -t seconds.
#     If the port responds, the IANA-registered service name is reported.
#     Otherwise, the service column reports "closed" or "filtered".

set -euo pipefail

HOST=""
PORTSPEC=""
OUTFILE=""
TIMEOUT=""

usage() {
    echo "Usage: $0 -h <ip> -p <ports> -o <output.csv> -t <timeout_seconds>" >&2
    echo "  -h must be a raw IPv4 address (no hostname resolution)" >&2
    echo "  -p accepts a range (1-65535), a list (80,443,445), or a single port (22)" >&2
    exit 2
}

die() {
    echo "Error: $*" >&2
    exit 2
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

while getopts ":h:p:o:t:" opt; do
    case "$opt" in
        h) HOST="$OPTARG" ;;
        p) PORTSPEC="$OPTARG" ;;
        o) OUTFILE="$OPTARG" ;;
        t) TIMEOUT="$OPTARG" ;;
        \?) echo "Error: invalid option -$OPTARG" >&2; usage ;;
        :) echo "Error: option -$OPTARG requires an argument" >&2; usage ;;
    esac
done

# All four parameters are mandatory
[[ -z "$HOST" ]]     && { echo "Error: -h <ip> is required" >&2; usage; }
[[ -z "$PORTSPEC" ]] && { echo "Error: -p <ports> is required" >&2; usage; }
[[ -z "$OUTFILE" ]]  && { echo "Error: -o <output.csv> is required" >&2; usage; }
[[ -z "$TIMEOUT" ]]  && { echo "Error: -t <timeout_seconds> is required" >&2; usage; }

if ! [[ "$TIMEOUT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: -t must be a positive number (seconds)" >&2
    exit 2
fi

require_cmd timeout

# --- Validate -h is a raw IPv4 address (no hostname resolution) -------------
if ! [[ "$HOST" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: -h must be a valid IPv4 address (e.g. 8.8.8.8), not a hostname" >&2
    exit 2
fi
for octet in ${HOST//./ }; do
    if (( octet > 255 )); then
        echo "Error: -h '$HOST' is not a valid IPv4 address" >&2
        exit 2
    fi
done

# --- Parse -p into an array of ports ---------------------------------------
PORTS=()

if [[ "$PORTSPEC" == *","* ]]; then
    IFS=',' read -ra PORTS <<< "$PORTSPEC"
elif [[ "$PORTSPEC" == *"-"* ]]; then
    PSTART="${PORTSPEC%%-*}"
    PEND="${PORTSPEC##*-}"
    if ! [[ "$PSTART" =~ ^[0-9]+$ && "$PEND" =~ ^[0-9]+$ ]]; then
        echo "Error: invalid range '$PORTSPEC'" >&2
        exit 2
    fi
    if (( PSTART > PEND )); then
        echo "Error: range start ($PSTART) is greater than end ($PEND)" >&2
        exit 2
    fi
    while IFS= read -r p; do PORTS+=("$p"); done < <(seq "$PSTART" "$PEND")
else
    PORTS=("$PORTSPEC")
fi

declare -A SEEN
CLEAN_PORTS=()
for p in "${PORTS[@]}"; do
    p="$(echo -n "$p" | tr -d '[:space:]')"
    if ! [[ "$p" =~ ^[0-9]+$ ]] || (( p < 1 || p > 65535 )); then
        echo "Error: invalid port '$p'" >&2
        exit 2
    fi
    if [[ -z "${SEEN[$p]:-}" ]]; then
        SEEN[$p]=1
        CLEAN_PORTS+=("$p")
    fi
done
PORTS=("${CLEAN_PORTS[@]}")

# --- Service name lookup -----------------------------------------------------
lookup_service() {
    local port="$1"
    local svc=""

    if command -v getent >/dev/null 2>&1; then
        svc=$(getent services "${port}/tcp" 2>/dev/null | awk '{print $1}')
    fi

    if [[ -z "$svc" && -r /etc/services ]]; then
        svc=$(awk -v p="${port}/tcp" '$2==p {print $1; exit}' /etc/services)
    fi

    [[ -z "$svc" ]] && svc="unknown"
    echo "$svc"
}

IP="$HOST"

output_dir="$(dirname -- "$OUTFILE")"
mkdir -p -- "$output_dir" || die "Unable to create output directory: $output_dir"

tmp_output="$(mktemp "${TMPDIR:-/tmp}/service-scan.XXXXXX")"
trap 'rm -f -- "$tmp_output"' EXIT

echo "ip,port,service" > "$tmp_output"

for port in "${PORTS[@]}"; do
    err=$(timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/${IP}/${port}" 2>&1)
    rc=$?

    if (( rc == 0 )); then
        exec 3>&- 3<&- 2>/dev/null || true
        svc=$(lookup_service "$port")
    elif (( rc == 124 )); then
        svc="filtered"
    else
        if [[ "$err" == *"refused"* ]]; then
            svc="closed"
        elif [[ "$err" == *"No route to host"* || "$err" == *"Network is unreachable"* ]]; then
            svc="filtered"
        else
            svc="closed"
        fi
    fi

    echo "$IP,$port,$svc" >> "$tmp_output"
done

mv "$tmp_output" "$OUTFILE"

echo
echo "[*] Done. Results saved to: $OUTFILE"

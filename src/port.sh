#!/usr/bin/env bash
#
# port.sh - Scan TCP port(s) on a host using bash's /dev/tcp technique
#           and write results to CSV: subdomain,ip,port,status
#
# Usage:
#   ./port.sh -h <ip> -p <ports> -o <output.csv> -t <timeout_seconds>
#
# -h must be a raw IPv4 address (hostnames are not resolved)
#
# -p accepts:
#   Range:         -p 1-65535
#   List:          -p 80,443,445
#   Single port:   -p 22
#
# Example:
#   ./port.sh -h 8.8.8.8 -p 80 -o output.csv -t 0.5
#
# Status values written to CSV:
#   open      - connection succeeded
#   closed    - connection actively refused (RST) before timeout
#   filtered  - no response within timeout (likely dropped by firewall/ACL)

set -uo pipefail

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

IP="$HOST"

echo "ip,port,status" > "$OUTFILE"

for port in "${PORTS[@]}"; do
    err=$(timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/${IP}/${port}" 2>&1)
    rc=$?

    if (( rc == 0 )); then
        status="open"
        exec 3>&- 3<&- 2>/dev/null || true
    elif (( rc == 124 )); then
        status="filtered"
    else
        if [[ "$err" == *"refused"* ]]; then
            status="closed"
        elif [[ "$err" == *"No route to host"* || "$err" == *"Network is unreachable"* ]]; then
            status="filtered"
        else
            status="closed"
        fi
    fi

    echo "$IP,$port,$status" | tee -a "$OUTFILE"
done

echo
echo "[*] Done. Results saved to: $OUTFILE"

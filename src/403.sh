#!/bin/bash

usage() {
    echo "Usage: $0 -h <URL> -o <output.csv>" >&2
    exit 1
}

url=""
outfile=""

while getopts ":h:o:" opt; do
    case "$opt" in
        h) url="$OPTARG" ;;
        o) outfile="$OPTARG" ;;
        \?) echo "Error: invalid option -$OPTARG" >&2; usage ;;
        :) echo "Error: option -$OPTARG requires an argument" >&2; usage ;;
    esac
done

if [ -z "$url" ]; then
    echo "Error: URL (-h) is required." >&2
    usage
fi

if [ -z "$outfile" ]; then
    echo "Error: output file (-o) is required." >&2
    usage
fi

echo "URL,Category,Payload,Status Code,Size" > "$outfile"

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
    result=$(curl -k -s -o /dev/null -L -w "%{http_code},%{size_download}" -X "$method" "$url")
    echo " -> $result" >&2
    echo "$url,Method,$method,$result" >> "$outfile"
done

echo >&2
echo "[*] Testing headers (${#http_headers[@]})..." >&2
for header in "${http_headers[@]}"; do
    count=$((count + 1))
    printf "  [%d/%d] Header: %-40s" "$count" "$total" "$header" >&2
    result=$(curl -k -s -o /dev/null -L -w "%{http_code},%{size_download}" -H "$header" "$url")
    echo " -> $result" >&2
    echo "$url,Header,$header,$result" >> "$outfile"
done

echo >&2
echo "[*] Done. Results saved to $outfile" >&2

#!/bin/bash

if [ -z "$2" ]; then
  echo "Usage: $0 <domain> <output.txt>" >&2
  exit 1
fi

if [[ "$2" != *.txt ]]; then
  echo "Error: output file must have a .txt extension" >&2
  exit 1
fi

subfinder -d "$1" -all -silent \
  | sed 's/^www\.//' \
  | sort -u \
  > "$2"

echo
echo "Subdomains written to $2"

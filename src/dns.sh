#!/bin/bash

if [ -z "$2" ]; then
  echo "Usage: $0 <url|subdomains.txt> <output.csv>" >&2
  exit 1
fi

if [[ "$2" != *.csv ]]; then
  echo "Error: output file must have a .csv extension" >&2
  exit 1
fi

clean_uri() {
  echo "$1" | sed -E 's#^[a-zA-Z]+://##' | sed -E 's#[:/].*$##' | sed 's/^www\.//'
}

# If $1 is a readable file, treat each non-empty line as a URI.
# Otherwise, treat $1 itself as a single URI.
# If $1 looks like a path to a file (contains a slash, or ends in .txt)
# but doesn't actually exist, fail loudly instead of silently treating it as a domain.
if [[ "$1" == *.txt || "$1" == */* ]] && [ ! -f "$1" ]; then
  echo "Error: file not found: $1" >&2
  exit 1
fi

if [ -f "$1" ]; then
  echo "Reading URIs from file: $1" >&2
  mapfile -t uris < <(tr -d '\r' < "$1" | grep -v '^[[:space:]]*$')
  echo "Loaded ${#uris[@]} URI(s)" >&2
  if [ "${#uris[@]}" -eq 0 ]; then
    echo "Error: no URIs found in $1" >&2
    exit 1
  fi
else
  echo "Treating input as a single URI: $1" >&2
  uris=("$1")
fi

{
  echo "URI,TTL,DNS Record,DNS Value"
  for raw_uri in "${uris[@]}"; do
    uri=$(clean_uri "$raw_uri")
    for rtype in A AAAA CNAME MX TXT NS SOA; do
      dig +noall +answer "$rtype" "$uri" | while read -r _ ttl _ rtype_col val; do
        if [ -n "$val" ]; then
          case "$val" in
            *,*) echo "$uri,$ttl,$rtype_col,\"$val\"" ;;
            *)   echo "$uri,$ttl,$rtype_col,$val" ;;
          esac
        fi
      done
    done
  done
} > "$2"

echo
echo "DNS results written to $2"
echo


#!/bin/bash
#
# Usage:  ./certcheck.sh <url|subdomains.txt> <output.csv>
#         SHORT=1 ./certcheck.sh hosts.txt out.csv    # subject/issuer reduced to CN only
#
# DNs contain commas (C=US, O=..., CN=...). Those become semicolons so
# `column -t -s, out.csv` keeps one row per host.

if [ -z "$2" ]; then
  echo "Usage: $0 <url|subdomains.txt> <output.csv>" >&2
  exit 1
fi

if [[ "$2" != *.csv ]]; then
  echo "Error: output file must have a .csv extension" >&2
  exit 1
fi

clean_uri() {
  echo "$1" | sed -E 's#^[a-zA-Z]+://##' | sed -E 's#[:/].*$##'
}

# commas -> semicolons, double quotes -> single, whitespace squeezed and trimmed
sanitize() {
  echo "$1" | sed 's/,/;/g' | sed 's/"/'"'"'/g' | tr -s ' ' | sed 's/^ *//; s/ *$//'
}

# pull just the CN out of a DN, fall back to the whole thing
cn_only() {
  local cn
  cn=$(echo "$1" | grep -oP 'CN\s*=\s*\K[^,/]+' | head -1)
  if [ -n "$cn" ]; then echo "$cn"; else echo "$1"; fi
}

# Fail loudly if $1 looks like a file path but doesn't exist
if [[ "$1" == *.txt || "$1" == *.csv || "$1" == *.list || "$1" == */* ]] && [ ! -f "$1" ]; then
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
  echo "URI,Cert Subject,Cert Issuer,Not Before,Not After,Days Until Expiry"

  for raw_uri in "${uris[@]}"; do
    uri=$(clean_uri "$raw_uri")

    cert=$(echo | openssl s_client -connect "${uri}:443" -servername "$uri" 2>/dev/null \
      | openssl x509 -noout -subject -issuer -dates 2>/dev/null)

    if [ -n "$cert" ]; then
      subject=$(echo "$cert" | grep '^subject=' | sed 's/^subject=//')
      issuer=$(echo "$cert" | grep '^issuer=' | sed 's/^issuer=//')
      not_before=$(echo "$cert" | grep '^notBefore=' | sed 's/^notBefore=//')
      not_after=$(echo "$cert" | grep '^notAfter=' | sed 's/^notAfter=//')

      if [ "${SHORT:-0}" = "1" ]; then
        subject=$(cn_only "$subject")
        issuer=$(cn_only "$issuer")
      fi

      subject=$(sanitize "$subject")
      issuer=$(sanitize "$issuer")
      not_before=$(sanitize "$not_before")
      not_after=$(sanitize "$not_after")

      if [ -n "$not_after" ]; then
        expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null)
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
    else
      echo "$uri,N/A,N/A,N/A,N/A,N/A"
    fi
  done
} > "$2"

sort -u "$2" -o "$2"

echo
echo "Certificate info written to $2"
echo

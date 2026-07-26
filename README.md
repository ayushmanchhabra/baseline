# Baseline

Collect subdomain, DNS, certificate and HTTP-method exposure data for a target domain.

## Requirements

1. Linux
2. `bash`
3. `openssl`
4. `subfinder`
5. `dig`
6. `curl`

## Getting Started

1. `git clone` the repo.
2. `chmod +x main.sh ./src/*.sh ./tests/test_validation.sh`
3. `./main.sh example.com ./out`
4. `column -t -s, ./out/dns_records.csv` to view DNS data nicely in the terminal

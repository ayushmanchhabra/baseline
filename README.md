# Baseline

Cybersecurity baseline for web applications.

## Requirements

1. Linux
1. bash
1. openssl
1. subfinder
1. dig
1. curl
1. timeout (usually provided by coreutils)
1. markdownlint

## Quick Start

1. Clone the repository.

1. Make the scripts executable:

   ```bash
   chmod +x main.sh ./src/*.sh ./tests/test_validation.sh
   ```

1. Run the full workflow against a domain:

   ```bash
   ./main.sh example.com ./out
   ```

1. Inspect the generated CSV files:

   ```bash
   column -t -s, ./out/dns_records.csv
   ```

The main workflow writes the following files into the output directory:

- subdomains.txt
- dns_records.csv
- tls_certificates.csv

## API Reference

This section documents how to use each script in the repository directly.

### 1. Main orchestration entrypoint

- Target script: main.sh
- Behavior: Runs the full workflow for a single hostname: subdomain discovery,
  DNS record collection, TLS certificate collection.

- Invocation:

  ```bash
  ./main.sh <domain> <output_dir>
  ```

- Example:

  ```bash
  ./main.sh example.com ./out
  ```

- Notes: The target must be a single hostname such as example.com or
  api.example.com. The output directory is created automatically if it does
  not exist.

### 2. Subdomain discovery

- Target script: src/sub.sh
- Behavior: Runs subfinder against a domain and writes a unique list of
  discovered subdomains.

- Invocation:

  ```bash
  ./src/sub.sh <domain> <output.txt>
  ```

- Example:

  ```bash
  ./src/sub.sh example.com ./subdomains.txt
  ```

- Output: A plain-text file containing one subdomain per line.

### 3. DNS record collection

- Target script: src/dns.sh
- Behavior: Queries common DNS record types for a hostname or a file of
  hostnames and writes CSV results.

- Invocation:

  ```bash
  ./src/dns.sh <hostname|subdomains.txt> <output.csv>
  ```

- Example:

  ```bash
  ./src/dns.sh example.com ./dns_records.csv
  ./src/dns.sh ./subdomains.txt ./out/dns_records.csv
  ```

- Output: A CSV with columns: URI, TTL, DNS Record, DNS Value.

### 4. TLS certificate collection

- Target script: src/crt.sh
- Behavior: Retrieves certificate details for one host or a list of hosts and
  writes them to CSV.

- Invocation:

  ```bash
  ./src/crt.sh <hostname|subdomains.txt> <output.csv>
  ```

- Example:

  ```bash
  ./src/crt.sh example.com ./tls_certificates.csv
  ./src/crt.sh ./subdomains.txt ./out/tls_certificates.csv
  ```

- Output: A CSV with columns: URI, Cert Subject, Cert Issuer, Not Before,
  Not After, Days Until Expiry.

### 5. HTTP method and header probing

- Target script: src/403.sh
- Behavior: Tests common HTTP methods and headers against a URL and writes
  the observed responses to CSV.

- Invocation:

  ```bash
  ./src/403.sh -h <URL> -o <output.csv>
  ```

- Example:

  ```bash
  ./src/403.sh -h https://example.com -o ./http_methods.csv
  ```

- Output: A CSV with columns: URL, Category, Payload, Status Code, Size.

### 6. TCP port scanning

- Target script: src/port.sh
- Behavior: Scans one or more TCP ports on a raw IPv4 address and writes the
  result to CSV.

- Invocation:

  ```bash
  ./src/port.sh -h <ip> -p <ports> -o <output.csv> -t <timeout_seconds>
  ```

- Example:

  ```bash
  ./src/port.sh -h 8.8.8.8 -p 80,443,445 -o ./out/ports.csv -t 1
  ```

- Output: A CSV with columns: ip, port, status.
- Notes: Only raw IPv4 addresses are accepted. Ports may be provided as a
  single port, a comma-separated list, or a range.

### 7. Service name lookup

- Target script: src/srv.sh
- Behavior: Checks TCP ports on a raw IPv4 address and reports the matching
  service name when available.

- Invocation:

  ```bash
  ./src/srv.sh -h <ip> -p <ports> -o <output.csv> -t <timeout_seconds>
  ```

- Example:

  ```bash
  ./src/srv.sh -h 8.8.8.8 -p 443 -o ./out/services.csv -t 0.5
  ```

- Output: A CSV with columns: ip, port, service.
- Notes: Only raw IPv4 addresses are accepted. Service names are resolved
  from system service data when available.

### Validation

Run the repository validation checks with:

```bash
./tests/test_validation.sh
```

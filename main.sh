#!/bin/bash

mkdir -p $2

./src/sub.sh $1 ./$2/subdomains.txt
./src/dns.sh ./$2/subdomains.txt ./$2/dns_records.csv
./src/crt.sh ./$2/subdomains.txt ./$2/tls_certificates.csv


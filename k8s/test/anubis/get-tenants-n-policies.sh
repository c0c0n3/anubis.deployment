#!/usr/bin/env bash

set -e -o pipefail


cluster_ip=$1
tenants_url="http://${cluster_ip}:9090/v1/tenants/"
policies_url="http://${cluster_ip}:9090/v1/policies/"

printf "\nAnubis tenants\n"
curl -v "$tenants_url"

printf "\nAnubis policies for Tenant1\n"
curl -v "$policies_url" -H 'fiware-service: Tenant1'

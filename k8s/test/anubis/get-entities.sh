#!/usr/bin/env bash

set -e -o pipefail


cluster_ip=$1
token_url="http://${cluster_ip}:8080/realms/default/protocol/openid-connect/token"
entities_url="http://${cluster_ip}:1026/v2/entities/"


source keycloak.sh

printf "\nGetting access token from Keycloak...\n"
token=$(get_ngsi_access_token "$token_url")
printf "Decoded access token:\n%s\n" "$(decode_access_token $token)"


printf "\nTenant1's NGSI entities\n"
curl -v "$entities_url" \
    -H 'fiware-service: Tenant1' \
    -H "Authorization: Bearer $token"

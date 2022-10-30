#!/usr/bin/env bash

set -e -o pipefail


cluster_ip=$1
token_url="http://${cluster_ip}:8080/realms/default/protocol/openid-connect/token"
entities_url="http://${cluster_ip}:1026/v2/entities/"


source keycloak.sh

printf "\nGetting access token from Keycloak...\n"
token=$(get_ngsi_access_token "$token_url")
printf "Decoded access token:\n%s\n" "$(decode_access_token $token)"


printf "\nCreating Tenant1's NGSI entity 'urn:ngsi-ld:AirQualityObserved:demo' under root path\n"
curl -v "$entities_url" \
    -H "Authorization: Bearer $token" \
    -H 'fiware-service: Tenant1' \
    -H 'fiware-ServicePath: /' \
    -H 'Content-Type: application/json' \
    -d '{
  "id": "urn:ngsi-ld:AirQualityObserved:demo",
  "type": "AirQualityObserved",
  "temperature": {
    "type": "Number",
    "value": 12.2,
    "metadata": {}
  }
}'
# See: https://github.com/orchestracities/anubis/blob/master/scripts/test_load.sh

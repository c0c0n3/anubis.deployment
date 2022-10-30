#!/usr/bin/env bash

# Tweaked from Anubis' own demo script for the Docker Compose tesbed
# - https://github.com/orchestracities/anubis/blob/master/scripts/run_demo.sh

set -e -o pipefail


cluster_ip=$1
token_url="http://${cluster_ip}:8080/realms/default/protocol/openid-connect/token"
tenants_url="http://${cluster_ip}:9090/v1/tenants/"
policies_url="http://${cluster_ip}:9090/v1/policies/"
# NOTE. Anubis chicken & egg problem.
# We need to set up tenants and policies before Anubis can enforce sec rules.
# But the policy API sits behind Envoy, which, thru OPA, delegates security
# to Anubis. So if you just try boostrapping security, you'll get fat 403s
# since there's no rules allowing you to get thru. Not sure how this is
# supposed to work, but as a workaround we expose port 9090 as a backdoor
# going straigth to the policy API, bypassing Envoy and OPA.

source keycloak.sh

printf "\nGetting access token from Keycloak...\n"
token=$(get_admin_access_token "$token_url")
printf "Decoded access token:\n%s\n" "$(decode_access_token $token)"


create_tenant() {
    curl -v "$tenants_url" \
        -H 'accept: */*' \
        -H "Authorization: Bearer $token" \
        -H 'Content-Type: application/json' \
        -d "$1"
}

printf "\nCreating Tenant1...\n"
create_tenant '{ "name": "Tenant1" }'

printf "\nCreating Tenant2...\n"
create_tenant '{ "name": "Tenant2" }'


create_policy() {
    curl -v $policies_url \
        -H 'accept: */*' \
        -H "Authorization: Bearer $token" \
        -H "fiware-service: $1" \
        -H 'fiware-servicepath: /' \
        -H 'Content-Type: application/json' \
        -d "$2"
}

printf "\nSetting up policies allowing Tenant1 to create entities under root path...\n"
create_policy "Tenant1" \
'{
"access_to": "*",
"resource_type": "entity",
"mode": ["acl:Write"],
"agent": ["acl:AuthenticatedAgent"]
}'

create_policy "Tenant1" \
'{
"access_to": "*",
"resource_type": "entity",
"mode": ["acl:Control"],
"agent": ["acl:AuthenticatedAgent"]
}'

create_policy "Tenant1" \
'{
"access_to": "*",
"resource_type": "policy",
"mode": ["acl:Read"],
"agent": ["acl:AuthenticatedAgent"]
}'

create_policy "Tenant1" \
'{
"access_to": "*",
"resource_type": "policy",
"mode": ["acl:Write"],
"agent": ["acl:AuthenticatedAgent"]
}'

create_policy "Tenant1" \
'{
"access_to": "Tenant1",
"resource_type": "tenant",
"mode": ["acl:Read"],
"agent": ["acl:AuthenticatedAgent"]
}'

create_policy "Tenant1" \
'{
"access_to": "Tenant1",
"resource_type": "tenant",
"mode": ["acl:Write"],
"agent": ["acl:AuthenticatedAgent"]
}'

create_policy "Tenant1" \
'{
"access_to": "/",
"resource_type": "service_path",
"mode": ["acl:Read"],
"agent": ["acl:AuthenticatedAgent"]
}'

create_policy "Tenant1" \
'{
"access_to": "/",
"resource_type": "service_path",
"mode": ["acl:Write"],
"agent": ["acl:AuthenticatedAgent"]
}'

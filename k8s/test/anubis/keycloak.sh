
get_admin_access_token() {
    local token_url=$1

    local token_response=$(
        curl -sS --location --request POST "$token_url" \
            --header 'Host: keycloak:8080' \
            --header 'Content-Type: application/x-www-form-urlencoded' \
            --data-urlencode 'username=admin@mail.com' \
            --data-urlencode 'password=admin' \
            --data-urlencode 'grant_type=password' \
            --data-urlencode 'client_id=configuration'
    )
    local token=$( jq -r ".access_token" <<<"$token_response" )

    echo $token
}

get_ngsi_access_token() {
    local token_url=$1

    local token_response=$(
        curl -s -X POST "$token_url" \
            --header 'Host: keycloak:8080' \
            -d "client_id=ngsi&client_secret=changeme&grant_type=password&username=admin@mail.com&password=admin"
    )
    local token=$( jq -r ".access_token" <<<"$token_response" )

    echo $token
}
# See: https://github.com/orchestracities/anubis/blob/master/scripts/test_load.sh

decode_access_token() {
    local token=$1

    local decoded_token=$(
        jq -R 'split(".") | .[1] | @base64d | fromjson' <<<"$token"
    )

    echo $decoded_token
}

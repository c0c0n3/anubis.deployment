#
# Dummy FIWARE policy.
# Only allow requests with a FIWARE service of "goodfellas".
# (I know I've got a sick sense of humour.)
#
# Example
#
# $ cd nix
# $ nix shell
# $ cd ../k8s/infra/security/rego
# $ opa eval 'data.fiware.service.allow' -i fiware/envoy-example-input.json -d ./
#   # ^ or equivalently
#   # opa eval 'allow' -i fiware/envoy-example-input.json -d ./ --package 'fiware.service'
#   # also try appending `-f values` for less verbose output.
#


package fiware.service

import data.config as config


default allow = false

allow {
    valid_request
}

valid_request {
    input.attributes.request.http.headers["fiware-service"] == "goodfellas"
}

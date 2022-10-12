#
# Basic tests for `service.rego`.
# TODO add test cases for corner cases, e.g. missing fields.
#
# To run the tests:
#
# $ cd nix
# $ nix shell
# $ cd ../k8s/infra/security/rego
# $ opa test . -v
#

package fiware.service


test_deny_tenant_mismatch {
    not allow with input as {
        "attributes": {
            "request": {
                "http": {
                    "headers": {
                        "fiware-service": "dodgy-tenant"
                    }
                }
            }
        }
    }
}

test_allow_expected_tenant {
    allow with input as {
        "attributes": {
            "request": {
                "http": {
                    "headers": {
                        "fiware-service": "goodfellas"
                    }
                }
            }
        }
    }
}

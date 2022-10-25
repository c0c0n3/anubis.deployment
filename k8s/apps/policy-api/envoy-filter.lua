common = (loadfile "/etc/envoy/lua/common.lua")()

function envoy_on_request(request_handle)
    common:management_api_request(request_handle)
end

function envoy_on_response(response_handle)
    common:management_api_response(response_handle)
end

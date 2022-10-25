common = (loadfile "/etc/envoy/lua/common.lua")()

function envoy_on_request(request_handle)
    common:context_broker_request(request_handle)
end

function envoy_on_response(response_handle)
    common:context_broker_response(response_handle)
end

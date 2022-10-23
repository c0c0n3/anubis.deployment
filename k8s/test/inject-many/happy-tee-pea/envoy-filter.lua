function envoy_on_request(request_handle)
end

function envoy_on_response(response_handle)
    response_handle:headers():add("greeting", "howzit!")
end

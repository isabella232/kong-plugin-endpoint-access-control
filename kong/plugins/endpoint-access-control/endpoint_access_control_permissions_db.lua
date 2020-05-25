local EndpointAccessControlPermissionsDb = {}

local function find_by_api_key_and_method(api_key, method)
    if not api_key then
        error({ msg = "Api key is required." })
    end

    if not method then
        error({ msg = "Method is required." })
    end

    local api_key_access_list, err = kong.db.connector:query(string.format("SELECT url_pattern FROM endpoint_access_control_permissions WHERE key = '%s' and method = '%s'", api_key, method))

    if err then
        error(err)
    end

    return api_key_access_list
end

function EndpointAccessControlPermissionsDb.find_by_api_key_and_method(api_key, method)
    return find_by_api_key_and_method(api_key, method)
end

return EndpointAccessControlPermissionsDb

local EndpointAccessControlPermissionsDb = {}

local function load_permission_setting(db, api_key, method)
    local api_key_access_list, err = db.connector:query(string.format("SELECT url_pattern FROM endpoint_access_control_permissions WHERE key = '%s' and method = '%s'", api_key, method))

    if err then
        error(err)
    end

    return api_key_access_list
end

local function get_cache_key(api_key, method)
    return "endpoint_access_control_permissions:" .. api_key .. ":" .. method
end

local function find_by_api_key_and_method(api_key, method)
    if not api_key then
        error({ msg = "Api key is required." })
    end

    if not method then
        error({ msg = "Method is required." })
    end

    local cache_key = get_cache_key(api_key, method)
    local api_key_access_list = kong.cache:get(cache_key, nil, load_permission_setting, kong.db, api_key, method)

    return api_key_access_list
end

function EndpointAccessControlPermissionsDb.find_by_api_key_and_method(api_key, method)
    return find_by_api_key_and_method(api_key, method)
end

return EndpointAccessControlPermissionsDb

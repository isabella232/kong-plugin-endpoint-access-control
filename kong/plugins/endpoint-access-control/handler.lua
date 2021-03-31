local BasePlugin = require "kong.plugins.base_plugin"
local Logger = require "logger"
local EndpointAccessControlPermissionsDb = require "kong.plugins.endpoint-access-control.endpoint_access_control_permissions_db"

local EndpointAccessControlHandler = BasePlugin:extend()

EndpointAccessControlHandler.PRIORITY = 950

function EndpointAccessControlHandler:new()
  EndpointAccessControlHandler.super.new(self, "endpoint-access-control")
end

local function get_replaced_path(path, path_replacements)
  for _, path_replacement in pairs(path_replacements) do
    local matcher, replacer = path_replacement:match("^(.+)|(.*)$")
    local corrected_path, replace_count = path:gsub(matcher, replacer)

    if replace_count > 0 then
      return corrected_path
    end
  end

  return path
end

local function access_for_api_key_and_method(api_key,  method, config)
  if not api_key or not method then
    error({message = "Missing api_key or method", api_key = api_key})
  end

  if string.find(api_key, "'") then
    error({message = "Consumer username contains illegal characters", api_key = api_key})
  end

  local api_key_endpoint_access_list = EndpointAccessControlPermissionsDb.find_by_api_key_and_method(api_key, method)

  local original_path = kong.request.get_path():lower()
  local path = get_replaced_path(original_path, config.path_replacements or {})

  for i = 1, #api_key_endpoint_access_list do
    if string.match(path, api_key_endpoint_access_list[i].url_pattern) then
      return true
    end
  end

  Logger.getInstance(ngx):logWarning({message = "Could not find any matching permission", api_key = api_key, request_fixed_path = path})
  kong.service.request.set_header("X-Missing-Api-Permission", true)
  return false
end

local function check_allowed_api_key_patterns(patterns, api_key)
  for i = 1, #patterns do
    if string.match(api_key, patterns[i]) then
      return true
    end
  end
  return false
end

function EndpointAccessControlHandler:access(config)
  EndpointAccessControlHandler.super.access(self)

  local api_key = kong.request.get_header("x-credential-username")

  if check_allowed_api_key_patterns(config.allowed_api_key_patterns, api_key) then
    return
  end

  local method = kong.request.get_method()

  local success, result = pcall(access_for_api_key_and_method, api_key, method, config)

  if success then
    if config.darklaunch then
      return
    end

    if not result then
      return kong.response.exit(403)
    end
  else
    Logger.getInstance(ngx):logError(result)
    return kong.response.exit(500, { message = "An unexpected error occurred." })
  end

end

return EndpointAccessControlHandler

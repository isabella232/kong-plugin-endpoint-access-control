local BasePlugin = require "kong.plugins.base_plugin"
local Logger = require "logger"
local EndpointAccessControlPermissionsDb = require "kong.plugins.endpoint-access-control.endpoint_access_control_permissions_db"

local EndpointAccessControlHandler = BasePlugin:extend()

EndpointAccessControlHandler.PRIORITY = 950

function EndpointAccessControlHandler:new()
  EndpointAccessControlHandler.super.new(self, "endpoint-access-control")
end

local function access_for_api_key_and_method(api_key,  method)
  if not api_key or not method then
    error({message = "Missing api_key or method", api_key = api_key})
  end

  if string.find(api_key, "'") then
    error({message = "Consumer username contains illegal characters", api_key = api_key})
  end

  local api_key_endpoint_access_list = EndpointAccessControlPermissionsDb.find_by_api_key_and_method(api_key, method)

  local path = kong.request.get_path()
  for i = 1, #api_key_endpoint_access_list do
    if string.match(path, api_key_endpoint_access_list[i].url_pattern) then
      return true
    end
  end

  Logger.getInstance(ngx):logWarning({message = "Could not find any matching permission", api_key = api_key})
  return false
end

function EndpointAccessControlHandler:access(config)
  EndpointAccessControlHandler.super.access(self)

  local api_key = kong.request.get_header("x-credential-username")
  local method = kong.request.get_method()

  local success, result = pcall(access_for_api_key_and_method, api_key, method)

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

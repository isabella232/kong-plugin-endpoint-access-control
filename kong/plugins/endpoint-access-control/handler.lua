local BasePlugin = require "kong.plugins.base_plugin"
local Logger = require "logger"
local EndpointAccessControlPermissionsDb = require "kong.plugins.endpoint-access-control.endpoint_access_control_permissions_db"

local EndpointAccessControlHandler = BasePlugin:extend()

EndpointAccessControlHandler.PRIORITY = 2000

function EndpointAccessControlHandler:new()
  EndpointAccessControlHandler.super.new(self, "endpoint-access-control")
end

function access_for_api_key_and_method(api_key,  method)
  if not api_key or not method then
    return kong.response.exit(403)
  end

  if string.find(api_key, "'") then
    kong.response.exit(500, { message = "Consumer username contains illegal characters." })
  end

  local api_key_endpoint_access_list = EndpointAccessControlPermissionsDb.find_by_api_key_and_method(api_key, method)

  local path = kong.request.get_path()
  for i = 1, #api_key_endpoint_access_list do
    if string.match(path, api_key_endpoint_access_list[i].url_pattern) then
      return
    end
  end

  return kong.response.exit(403)
end

function EndpointAccessControlHandler:access(config)
  EndpointAccessControlHandler.super.access(self)

  if config.darklaunch then
    return
  end

  local api_key = kong.request.get_header("x-consumer-username")
  local method = kong.request.get_method()

  local success = pcall(access_for_api_key_and_method, api_key, method)

  if not success then
    Logger.getInstance(ngx):logError(result)

    return kong.response.exit(500, { message = "An unexpected error occurred." })
  end

end

return EndpointAccessControlHandler

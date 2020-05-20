local BasePlugin = require "kong.plugins.base_plugin"
local Logger = require "logger"

local EndpointAccessControlHandler = BasePlugin:extend()

EndpointAccessControlHandler.PRIORITY = 2000

function EndpointAccessControlHandler:new()
  EndpointAccessControlHandler.super.new(self, "endpoint-access-control")
end

function EndpointAccessControlHandler:access(config)
  EndpointAccessControlHandler.super.access(self)

  if config.darklaunch then
    return
  end

  return kong.response.exit(403)
end

return EndpointAccessControlHandler

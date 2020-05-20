package = "kong-plugin-endpoint-access-control"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}
source = {
  url = "git+https://github.com/emartech/kong-plugin-endpoint-access-control.git",
  tag = "0.1.0"
}
description = {
  summary = "Endpoint Access Control for Kong API gateway plugins.",
  homepage = "https://github.com/emartech/kong-plugin-endpoint-access-control",
  license = "MIT"
}
dependencies = {
  "lua ~> 5.1",
  "classic 0.1.0-1",
  "kong-lib-logger >= 0.3.0-1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.endpoint-access-control.handler"] = "kong/plugins/endpoint-access-control/handler.lua",
    ["kong.plugins.endpoint-access-control.schema"] = "kong/plugins/endpoint-access-control/schema.lua",
  }
}

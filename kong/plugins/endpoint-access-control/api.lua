local endpoints = require "kong.api.endpoints"
local Logger = require("logger")

local schema = kong.db.endpoint_access_control_permissions.schema

return {
  ["/endpoint-access-control/allowed-endpoints"] = {
    schema = schema,
    methods = {
      POST = function(self, db, helpers)
        return endpoints.post_collection_endpoint(schema)(self, db, helpers)
      end
    }
  },
  ["/endpoint-access-control/keys/:key/allowed-endpoints"] = {
    schema = schema,
    methods = {
      GET = function(self, db, helpers)
        local query = string.format("SELECT * FROM endpoint_access_control_permissions WHERE key = '%s'", self.params.key)
        local allowed_endpoints, err = kong.db.connector:query(query)

        if err then
          Logger.getInstance(ngx):logError({
            msg = err,
          })
          return kong.response.exit(500, "Database error")
        end

        if #allowed_endpoints == 0 then
          return kong.response.exit(404, "The requested resource does not exist")
        end

        return kong.response.exit(200, { allowed_endpoints = allowed_endpoints})
      end
    }
  }
}

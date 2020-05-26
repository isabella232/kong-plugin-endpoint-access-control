local endpoints = require "kong.api.endpoints"
local Logger = require("logger")

local schema = kong.db.endpoint_access_control_permissions.schema

return {
  ["/allowed-endpoints"] = {
    schema = schema,
    methods = {
      POST = function(self, db, helpers)
        return endpoints.post_collection_endpoint(schema)(self, db, helpers)
      end
    }
  },
  ["/allowed-endpoints/:id"] = {
    schema = schema,
    methods = {
      DELETE = function(self, db, helpers)
        local query = string.format("DELETE FROM endpoint_access_control_permissions WHERE id = '%s'", self.params.id)
        local result, err = kong.db.connector:query(query)

        if err then
          Logger.getInstance(ngx):logError({
            msg = err,
          })
          return kong.response.exit(500, "Database error")
        end

        if result.affected_rows == 0 then
          return kong.response.exit(404, "The requested resource does not exist")
        end

        return kong.response.exit(204)
      end
    }
  },
  ["/allowed-endpoints/keys/:key"] = {
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

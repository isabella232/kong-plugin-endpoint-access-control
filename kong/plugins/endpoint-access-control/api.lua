local endpoints = require "kong.api.endpoints"
local Logger = require("logger")

local schema = kong.db.endpoint_access_control_permissions.schema

local function get_cache_key(api_key, method)
  return "endpoint_access_control_permissions:" .. api_key .. ":" .. method
end

local function decode_url(key)
  local decode_map = {
    { pattern = "%%20", replacement = " " },
    { pattern = "+", replacement = " " },
    { pattern = "%%26", replacement = "&" },
  }

  local decoded_key = key

  for _, decode_rule in pairs(decode_map) do
    decoded_key = decoded_key:gsub(decode_rule["pattern"], decode_rule["replacement"])
  end

  return decoded_key
end

return {
  ["/allowed-endpoints"] = {
    schema = schema,
    methods = {
      POST = function(self, db, helpers)
        if self.params.key and self.params.method then
          local cache_key = get_cache_key(self.params.key, self.params.method)
          kong.cache:invalidate(cache_key)
        end

        return endpoints.post_collection_endpoint(schema)(self, db, helpers)
      end
    }
  },
  ["/allowed-endpoints/:id"] = {
    schema = schema,
    methods = {
      DELETE = function(self, db, helpers)
        local entity = db[schema.name]:select({id = self.params.id})
        local success, err = db[schema.name]:delete({id = self.params.id})

        if not success then
          Logger.getInstance(ngx):logError({
            msg = err,
          })
          return kong.response.exit(500, "Database error")
        end

        if entity then
          local cache_key = get_cache_key(entity.key, entity.method)
          kong.cache:invalidate(cache_key)
        end

        return kong.response.exit(204)
      end
    }
  },
  ["/allowed-endpoints/keys/:key"] = {
    schema = schema,
    methods = {
      GET = function(self, db, helpers)
        local key = decode_url(self.params.key)
        local query = string.format("SELECT * FROM endpoint_access_control_permissions WHERE key = '%s'", key:gsub("'", ""))
        local allowed_endpoints, err = kong.db.connector:query(query)

        if err then
          Logger.getInstance(ngx):logError({
            msg = err,
          })
          return kong.response.exit(500, "Database error")
        end

        return kong.response.exit(200, { allowed_endpoints = allowed_endpoints })
      end
    }
  }
}

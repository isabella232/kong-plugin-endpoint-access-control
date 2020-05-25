local typedefs = require "kong.db.schema.typedefs"

return {
  endpoint_access_control_permissions = {
    name = "endpoint_access_control_permissions",
    primary_key = { "id" },
    cache_key = { "key", "method", "url_pattern" },
    generate_admin_api = false,
    endpoint_key = "key",
    fields = {
      { id = typedefs.uuid },
      { created_at = typedefs.auto_timestamp_s },
      {
        key = {
          type = "string",
          required = true
        }
      },
      {
        method = {
          type = "string",
          required = true,
          one_of = { "GET", "POST", "PUT", "PATCH", "DELETE" }
        }
      },
      {
        url_pattern = {
          type = "string",
          required = true
        }
      }
    }
  }
}

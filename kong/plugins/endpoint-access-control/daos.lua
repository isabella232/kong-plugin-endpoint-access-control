local typedefs = require "kong.db.schema.typedefs"

return { endpoint_access_control_permissions = {
    name = "endpoint_access_control_permissions",
    primary_key = { "id" },
    cache_key = { "key", "method", "url_pattern" },
    generate_admin_api = false,
    endpoint_key = "key",
    fields = {
        { id = typedefs.uuid },
        --{ created_at = { type = "string" } },
        { key = { type = "string" } },
        { method = { type = "string" } },
        { url_pattern = { type = "string" } },
    }
} }
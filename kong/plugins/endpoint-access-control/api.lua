local endpoints = require "kong.api.endpoints"

local schema = kong.db.endpoint_access_control_permissions.schema

return {
    ["/endpoint-access-control/allowed-endpoints"] = {
        schema = schema,
        methods = {
            POST = function(self, db, helpers)
                return endpoints.post_collection_endpoint(schema)(self, db, helpers)
            end
        }
    }
}
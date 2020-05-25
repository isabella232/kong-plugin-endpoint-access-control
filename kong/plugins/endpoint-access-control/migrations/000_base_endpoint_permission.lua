return {
    postgres = {
        up = [[
            CREATE TABLE IF NOT EXISTS endpoint_access_control_permissions (
                id UUID,
                created_at TIMESTAMP WITHOUT TIME ZONE,
                key TEXT,
                method TEXT,
                url_pattern TEXT,
                cache_key TEXT UNIQUE,
                PRIMARY KEY (id),
                UNIQUE (key, method, url_pattern)
              );

            CREATE INDEX IF NOT EXISTS endpoint_access_control_permissions_key_idx ON endpoint_access_control_permissions(key);
            CREATE INDEX IF NOT EXISTS endpoint_access_control_permissions_method_idx ON endpoint_access_control_permissions(method);
            CREATE INDEX IF NOT EXISTS endpoint_access_control_permissions_url_pattern_idx ON endpoint_access_control_permissions(url_pattern);

        ]]
    },
    cassandra = {
            up = [[]]
    }
}
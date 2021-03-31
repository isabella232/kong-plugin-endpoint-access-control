return {
  name = "endpoint-access-control",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          {
            darklaunch = {
              type = "boolean",
              default = false
            }
          },
          {
            path_replacements = {
              type = "array",
              elements = {
                type = "string"
              },
              default = {}
            }
          },
          {
            allowed_api_key_patterns = {
              type = "array",
              elements = {
                type = "string"
              },
              default = {}
            }
          }
        }
      }
    }
  }
}
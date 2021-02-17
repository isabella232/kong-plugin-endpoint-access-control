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
          }
        }
      }
    }
  }
}
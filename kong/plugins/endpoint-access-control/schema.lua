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
          }
        }
      }
    }
  }
}
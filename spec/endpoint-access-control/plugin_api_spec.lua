local helpers = require "spec.helpers"
local kong_client = require "kong_client.spec.test_helpers"

describe("EndpointAccessControl", function()
  local kong_sdk, send_request, send_admin_request

  setup(function()
    helpers.start_kong({ plugins = "endpoint-access-control" })

    kong_sdk = kong_client.create_kong_client()
    send_request = kong_client.create_request_sender(helpers.proxy_client())
    send_admin_request = kong_client.create_request_sender(helpers.admin_client())
  end)

  teardown(function()
    helpers.stop_kong(nil)
  end)

  before_each(function()
    helpers.db:truncate()
  end)

  context("API", function()
    context("POST new permission setting", function()

      it("should respond with 201 on success", function ()

        local response = send_admin_request({
          method = "POST",
          path = "/endpoint-access-control/allowed-endpoints",
          body = {
              key = 'key001',
              method = 'GET',
              url_pattern = "^/v2/email$"
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        assert.are.equals(201, response.status)
      end)

    end)
  end)
end)

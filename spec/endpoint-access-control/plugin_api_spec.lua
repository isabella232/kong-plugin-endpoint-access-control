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
            key = "key001",
            method = "GET",
            url_pattern = "/api/v1/foobar"
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        assert.are.equals(201, response.status)
      end)

      it("should respond with 400 on missing fields", function ()
        local response = send_admin_request({
          method = "POST",
          path = "/endpoint-access-control/allowed-endpoints",
          body = {},
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        assert.are.equals(400, response.status)
        assert.are.same({
          method = "required field missing",
          url_pattern = "required field missing",
          key = "required field missing"
        }, response.body.fields)
      end)

      local accepted_methods = { "GET", "POST", "PUT", "PATCH", "DELETE" }

      for _, http_method in pairs(accepted_methods) do
        it("should accept '" .. http_method .. "' method in payload", function ()
          local response = send_admin_request({
            method = "POST",
            path = "/endpoint-access-control/allowed-endpoints",
            body = {
              key = "key001",
              method = http_method,
              url_pattern = "/api/v1/foobar"
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })

          assert.are.equals(201, response.status)
        end)
      end

      local some_invalid_methods = { "get", "foo", "" }

      for _, http_method in pairs(some_invalid_methods) do
        it("should refuse '" .. http_method .. "' method in payload", function ()
          local response = send_admin_request({
            method = "POST",
            path = "/endpoint-access-control/allowed-endpoints",
            body = {
              key = "key001",
              method = http_method,
              url_pattern = "/api/v1/foobar"
            },
            headers = {
              ["Content-Type"] = "application/json"
            }
          })

          assert.are.equals(400, response.status)
          assert.are.same({
            method = "expected one of: GET, POST, PUT, PATCH, DELETE"
          }, response.body.fields)
        end)
      end

    end)
  end)
end)

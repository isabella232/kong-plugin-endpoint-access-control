local helpers = require "spec.helpers"
local match = require "luassert.match"
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

      it("should add created_at field with timestamp on success", function ()
        local response = send_admin_request({
          method = "POST",
          path = "/endpoint-access-control/allowed-endpoints",
          body = {
            key = "key001",
            method = "POST",
            url_pattern = "/api/v1/foobar"
          },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        assert.is_true(response.body.created_at > 0)
      end)
    end)

    context("GET existing permission setting #only", function()

      it("should return the permission setting to the specific key when it exists", function ()

        local settings = {
          { key = "key001", method = "POST", url_pattern = "/api/v1/foobar" },
          { key = "key001", method = "GET", url_pattern = "/api/v1/foobar/2" },
          { key = "key002", method = "GET", url_pattern = "/api/v1/foobar/bar" }
        }

        for _, setting in ipairs(settings) do
          send_admin_request({
            method = "POST",
            path = "/endpoint-access-control/allowed-endpoints",
            body = setting,
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
        end

        local response = send_admin_request({
          method = "GET",
          path = "/endpoint-access-control/keys/key001/allowed-endpoints",
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        assert.are.equals(200, response.status)

        local allowed_endpoints = {
          { key = "key001", method = "POST", url_pattern = "/api/v1/foobar" },
          { key = "key001", method = "GET", url_pattern = "/api/v1/foobar/2" },
        }

        for index, entpoint in pairs(allowed_endpoints) do
          assert.are.equals(response.body.allowed_endpoints[index].key, entpoint.key)
          assert.are.equals(response.body.allowed_endpoints[index].method, entpoint.method)
          assert.are.equals(response.body.allowed_endpoints[index].url_pattern, entpoint.url_pattern)
        end

      end)

      it("should return 404 when the key does not exists", function ()
        local response = send_admin_request({
          method = "GET",
          path = "/endpoint-access-control/keys/key001/allowed-endpoints",
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        assert.are.equals(404, response.status)
      end)

      it("should return 500 when database error occurred", function ()
        local response = send_admin_request({
          method = "GET",
          path = "/endpoint-access-control/keys/'/allowed-endpoints",
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        assert.are.equals(500, response.status)
        assert.are.equals("Database error", response.body)
      end)
    end)
  end)
end)

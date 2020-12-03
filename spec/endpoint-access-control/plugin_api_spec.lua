local helpers = require "spec.helpers"
local kong_client = require "kong_client.spec.test_helpers"
local Logger = require("logger")

kong = kong or {}
kong.db = kong.db or {
  endpoint_access_control_permissions = {
    schema = {}
  }
}

local api = require "kong.plugins.endpoint-access-control.api"

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
          path = "/allowed-endpoints",
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
          path = "/allowed-endpoints",
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
            path = "/allowed-endpoints",
            body = {
              key = "key002",
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
            path = "/allowed-endpoints",
            body = {
              key = "key003",
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
          path = "/allowed-endpoints",
          body = {
            key = "key004",
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

    context("GET existing permission setting", function()

      it("should return the permission setting to the specific key when it exists", function ()

        local settings = {
          { key = "key005", method = "POST", url_pattern = "/api/v1/foobar" },
          { key = "key005", method = "GET", url_pattern = "/api/v1/foobar/2" },
          { key = "key006", method = "GET", url_pattern = "/api/v1/foobar/bar" }
        }

        for _, setting in ipairs(settings) do
          send_admin_request({
            method = "POST",
            path = "/allowed-endpoints",
            body = setting,
            headers = {
              ["Content-Type"] = "application/json"
            }
          })
        end

        local response = send_admin_request({
          method = "GET",
          path = "/allowed-endpoints/keys/key005"
        })

        assert.are.equals(200, response.status)
        assert.are.equals(2, #response.body.allowed_endpoints)
      end)

      it("should return 404 when the key does not exists", function ()
        local response = send_admin_request({
          method = "GET",
          path = "/allowed-endpoints/keys/key007/"
        })

        assert.are.equals(200, response.status)
        assert.are.same({}, response.body.allowed_endpoints)
      end)

      it("should return 500 when database error occurred", function ()
        Logger.getInstance = function()
          return {
            logError = function() end
          }
        end

        kong.db.connector = {
          query = function (self, query)
            return {}, "some error occured"
          end
        }

        kong.response = {
          exit = spy.new(function() end)
        }

        local api_handler = api["/allowed-endpoints/keys/:key"].methods

        api_handler.GET({ params = { key = "key007" } })

        assert.spy(kong.response.exit).was.called_with(500, "Database error")
      end)

      it("should handle sql injection", function ()
        send_admin_request({
          method = "POST",
          path = "/allowed-endpoints",
          body = { key = "key005", method = "GET", url_pattern = "/api/v1/foobar" },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        local response = send_admin_request({
          method = "GET",
          path = "/allowed-endpoints/keys/key005'--"
        })

        assert.are.equals(200, response.status)
        assert.are.same({}, response.body.allowed_endpoints)
      end)
    end)

    context("DELETE existing permission setting", function()

      it("should return the permission setting to the specific key when it exists", function ()

        local setting_creation_response = send_admin_request({
          method = "POST",
          path = "/allowed-endpoints",
          body = { key = "key008", method = "POST", url_pattern = "/api/v1/foobar" },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        local delete_response = send_admin_request({
          method = "DELETE",
          path = "/allowed-endpoints/" .. setting_creation_response.body.id,
        })

        assert.are.equals(204, delete_response.status)
      end)

      it("should return 500 when database error occurred", function ()
        local response = send_admin_request({
          method = "DELETE",
          path = "/allowed-endpoints/123",
        })

        assert.are.equals(500, response.status)
        assert.are.equals("Database error", response.body)
      end)

    end)

    context("Cache invalidation", function()

      local service

      before_each(function()
        service = kong_sdk.services:create({
          name = "test-service",
          url = "http://mockbin:8080/request"
        })

        kong_sdk.routes:create_for_service(service.id, "/test")

        kong_sdk.plugins:create({
          service = {
            id = service.id
          },
          name = "endpoint-access-control",
          config = {}
        })
      end)

      it("should invalidate cache on entity delete #only", function ()

        local setting_creation_response = send_admin_request({
          method = "POST",
          path = "/allowed-endpoints",
          body = { key = "key009", method = "POST", url_pattern = "^/test/%d+$" },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        local first_response = send_request({
          method = "POST",
          path = "/test/1234",
          headers = {
            ["x-credential-username"] = "key009"
          }
        })

        assert.are.equal(200, first_response.status)

        local delete_response = send_admin_request({
          method = "DELETE",
          path = "/allowed-endpoints/" .. setting_creation_response.body.id,
        })

        assert.are.equals(204, delete_response.status)

        local cache_key = "endpoint_access_control_permissions:key009:POST"
        helpers.wait_for_invalidation(cache_key)

        local second_response = send_request({
          method = "POST",
          path = "/test/1234",
          headers = {
            ["x-credential-username"] = "key009"
          }
        })

        assert.are.equal(403, second_response.status)
      end)

      it("should invalidate cache on entity create", function ()
        local first_response = send_request({
          method = "POST",
          path = "/test/1234",
          headers = {
            ["x-credential-username"] = "key010"
          }
        })

        assert.are.equal(403, first_response.status)

        send_admin_request({
          method = "POST",
          path = "/allowed-endpoints",
          body = { key = "key010", method = "POST", url_pattern = "^/test/%d+$" },
          headers = {
            ["Content-Type"] = "application/json"
          }
        })

        local second_response = send_request({
          method = "POST",
          path = "/test/1234",
          headers = {
            ["x-credential-username"] = "key010"
          }
        })

        assert.are.equal(200, second_response.status)
      end)
    end)
  end)
end)

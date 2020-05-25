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

  context("Plugin", function()

    local service, consumer

    before_each(function()
      service = kong_sdk.services:create({
        name = "test-service",
        url = "http://mockbin:8080/request"
      })

      kong_sdk.routes:create_for_service(service.id, "/test")

      consumer = kong_sdk.consumers:create({
        username = "test-consumer"
      })
    end)

    it("should set config default values", function()
      local response = kong_sdk.plugins:create({
        service = {
          id = service.id
        },
        name = "endpoint-access-control",
        config = {}
      })

      assert.are.same({
        darklaunch = false
      }, response.config)
    end)

    it("should terminate request with 403 http status", function()
      kong_sdk.plugins:create({
        service = {
          id = service.id
        },
        name = "endpoint-access-control",
        config = {}
      })

      local response = send_request({
        method = "GET",
        path = "/test"
      })

      assert.are.equal(403, response.status)
    end)

    it("should not terminate request when darklaunch mode is on", function()
      kong_sdk.plugins:create({
        consumer = {
          id = consumer.id
        },
        name = "endpoint-access-control",
        config = {
          darklaunch = true
        }
      })

      local response = send_request({
        method = "GET",
        path = "/test"
      })

      assert.are.equal(200, response.status)
    end)

    it("should not terminate request when api call is enabled for the api user", function()
      local api_user_endpoint_access = helpers.db.endpoint_access_control_permissions:insert({
        key = "test_user_wsse",
        method = "POST",
        url_pattern = "/test"
      })

      kong_sdk.plugins:create({
        service = {
          id = service.id
        },
        name = "endpoint-access-control",
        config = {
          darklaunch = false
        }
      })

      local response = send_request({
        method = "POST",
        path = "/test",
        headers = {
          ["x-consumer-username"] = "test_user_wsse"
        }
      })

      assert.are.equal(200, response.status)
    end)

    it("should terminate request when api call is not enabled for the api user", function()
      local api_user_endpoint_access = helpers.db.endpoint_access_control_permissions:insert({
        key = "test_user_wsse",
        method = "POST",
        url_pattern = "/test_not_matching"
      })

      kong_sdk.plugins:create({
        service = {
          id = service.id
        },
        name = "endpoint-access-control",
        config = {
          darklaunch = false
        }
      })

      local response = send_request({
        method = "POST",
        path = "/test",
        headers = {
          ["x-consumer-username"] = "test_user_wsse"
        }
      })

      assert.are.equal(403, response.status)
    end)

    it("should terminate request when there is no allowed endpoints for the consumer", function()
      kong_sdk.plugins:create({
        service = {
          id = service.id
        },
        name = "endpoint-access-control",
        config = {
          darklaunch = false
        }
      })

      local response = send_request({
        method = "POST",
        path = "/test",
        headers = {
          ["x-consumer-username"] = "test_user_wsse"
        }
      })

      assert.are.equal(403, response.status)
    end)

    it("should allow request when the request path matches the url pattern", function()
      local api_user_endpoint_access = helpers.db.endpoint_access_control_permissions:insert({
        key = "test_user_wsse",
        method = "POST",
        url_pattern = "^/test/%d+$"
      })

      kong_sdk.plugins:create({
        service = {
          id = service.id
        },
        name = "endpoint-access-control",
        config = {
          darklaunch = false
        }
      })

      local response = send_request({
        method = "POST",
        path = "/test/1234",
        headers = {
          ["x-consumer-username"] = "test_user_wsse"
        }
      })

      assert.are.equal(200, response.status)
    end)

    it("should allow request when the request with query params matches url pattern", function()
      local api_user_endpoint_access = helpers.db.endpoint_access_control_permissions:insert({
        key = "test_user_wsse",
        method = "POST",
        url_pattern = "^/test/%d+$"
      })

      kong_sdk.plugins:create({
        service = {
          id = service.id
        },
        name = "endpoint-access-control",
        config = {
          darklaunch = false
        }
      })

      local response = send_request({
        method = "POST",
        path = "/test/1234?test=1",
        headers = {
          ["x-consumer-username"] = "test_user_wsse"
        }
      })

      assert.are.equal(200, response.status)
    end)

    it("should terminate request when the request path with request method does not match any enabled endpoint", function()
      local api_user_endpoint_access = helpers.db.endpoint_access_control_permissions:insert({
        key = "test_user_wsse",
        method = "POST",
        url_pattern = "^/test/%d+$"
      })

      kong_sdk.plugins:create({
        service = {
          id = service.id
        },
        name = "endpoint-access-control",
        config = {
          darklaunch = false
        }
      })

      local response = send_request({
        method = "GET",
        path = "/test/1234",
        headers = {
          ["x-consumer-username"] = "test_user_wsse"
        }
      })

      assert.are.equal(403, response.status)
    end)

    -- it("should respond with 500 when user is invalid", function()
    --   local api_user_endpoint_access = helpers.db.endpoint_access_control_permissions:insert({
    --     key = "test_user_wsse",
    --     method = "POST",
    --     url_pattern = "^/test/%d+$"
    --   })

    --   kong_sdk.plugins:create({
    --     service = {
    --       id = service.id
    --     },
    --     name = "endpoint-access-control",
    --     config = {
    --       darklaunch = false
    --     }
    --   })

    --   local response = send_request({
    --     method = "GET",
    --     path = "/test/1234",
    --     headers = {
    --       ["x-consumer-username"] = "' or 1=1;--"
    --     }
    --   })

    --   assert.are.equal(500, response.status)
    -- end)
  end)
end)

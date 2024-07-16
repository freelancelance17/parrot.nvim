local assert = require("luassert")
local spy = require("luassert.spy")
local mock = require("luassert.mock")

-- Mock the required modules
local logger_mock = mock(require("parrot.logger"), true)
local utils_mock = mock(require("parrot.utils"), true)

-- Load the Gemini class
local Gemini = require("parrot.provider.gemini")

describe("Gemini", function()
  local gemini

  before_each(function()
    gemini = Gemini:new("https://generativelanguage.googleapis.com/v1beta/models/", "test_api_key")
  end)

  describe("process_onexit", function()
    it("should log an error message when there's an API error", function()
      local input = vim.json.encode({
        error = {
          code = 400,
          message = "API key not valid. Please pass a valid API key.",
          status = "INVALID_ARGUMENT",
          details = {
            {
              ["@type"] = "type.googleapis.com/google.rpc.ErrorInfo",
              reason = "API_KEY_INVALID",
              domain = "googleapis.com",
              metadata = {
                service = "generativelanguage.googleapis.com",
              },
            },
          },
        },
      })

      gemini:process_onexit(input)

      assert.spy(logger_mock.error).was_called_with(
        "GEMINI - code: 400 message:API key not valid. Please pass a valid API key. status:INVALID_ARGUMENT"
      )
    end)

    it("should not log anything for successful responses", function()
      local input = vim.json.encode({ success = true })

      gemini:process_onexit(input)

      assert.spy(logger_mock.error).was_not_called()
    end)

    it("should handle invalid JSON gracefully", function()
      local input = "invalid json"

      gemini:process_onexit(input)

      assert.spy(logger_mock.error).was_not_called()
    end)
  end)

  describe("process_stdout", function()
    it("should extract text from a valid response", function()
      local input = [[
        {"candidates": [{"content": {"parts": [{"text": "-identification. \n"}],"role": "model"},"finishReason": "STOP","index":
        0,"safetyRatings": [{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 163,"candidatesTokenCount": 4,"totalTokenCount": 167}}
      ]]

      local result = gemini:process_stdout(input)

      assert.equals("-identification. \n", result)
    end)

    it("should return nil for responses without text", function()
      local input = '{"candidates": [{"content": {"parts": [{}],"role": "model"}}]}'

      local result = gemini:process_stdout(input)

      assert.is_nil(result)
    end)

    it("should handle invalid JSON gracefully", function()
      local input = "invalid json"

      local result = gemini:process_stdout(input)

      assert.is_nil(result)
    end)

    it("should handle empty input gracefully", function()
      local input = ""

      local result = gemini:process_stdout(input)

      assert.is_nil(result)
    end)
  end)

  describe("set_model", function()
    it("should set the model correctly when given a string", function()
      gemini:set_model("gemini-1.5-pro")
      assert.equals("gemini-1.5-pro", gemini._model)
    end)

    it("should set the model correctly when given a table", function()
      gemini:set_model({ model = "gemini-1.5-flash" })
      assert.equals("gemini-1.5-flash", gemini._model)
    end)
  end)

  describe("preprocess_payload", function()
    it("should process messages correctly", function()
      local payload = {
        messages = {
          { role = "system", content = "You are a helpful assistant." },
          { role = "user", content = "Hello!" },
          { role = "assistant", content = "Hi there!" },
        }
      }

      local result = gemini:preprocess_payload(payload)

      assert.equals("You are a helpful assistant.", result.system_instruction.parts.text)
      assert.equals(2, #result.contents)
      assert.equals("user", result.contents[1].role)
      assert.equals("Hello!", result.contents[1].parts[1].text)
      assert.equals("model", result.contents[2].role)
      assert.equals("Hi there!", result.contents[2].parts[1].text)
    end)
  end)

  describe("verify", function()
    it("should return true for a valid API key", function()
      assert.is_true(gemini:verify())
    end)

    it("should return false and log an error for an invalid API key", function()
      gemini.api_key = ""
      assert.is_false(gemini:verify())
      assert.spy(logger_mock.error).was_called()
    end)
  end)

  describe("check", function()
    it("should return true for supported models", function()
      assert.is_true(gemini:check({ model = "gemini-1.5-pro" }))
      assert.is_true(gemini:check({ model = "gemini-1.5-flash" }))
    end)

    it("should return false for unsupported models", function()
      assert.is_false(gemini:check({ model = "unsupported-model" }))
    end)
  end)
end)

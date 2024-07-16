local logger = require("parrot.logger")
local utils = require("parrot.utils")

local OpenAI = {}
OpenAI.__index = OpenAI

local available_model_set = {
  ["gpt-4o"] = true,
  ["gpt-4o-2024-05-13"] = true,
  ["gpt-4-turbo-2024-04-09"] = true,
  ["gpt-4-0613"] = true,
  ["gpt-4-turbo"] = true,
  ["gpt-4"] = true,
  ["gpt-4-1106-vision-preview"] = true,
  ["gpt-4-1106-preview"] = true,
  ["gpt-3.5-turbo-16k"] = true,
  ["gpt-3.5-turbo-0613"] = true,
  ["gpt-3.5-turbo-0301"] = true,
  ["gpt-3.5-turbo-instruct-0914"] = true,
  ["gpt-3.5-turbo-instruct"] = true,
  ["gpt-4-0125-preview"] = true,
  ["gpt-3.5-turbo-16k-0613"] = true,
  ["gpt-4-turbo-preview"] = true,
  ["gpt-3.5-turbo-0125"] = true,
  ["gpt-3.5-turbo-1106"] = true,
  ["gpt-3.5-turbo"] = true,
}

-- https://platform.openai.com/docs/api-reference/chat/create
local available_api_parameters = {
  -- required
  ["messages"] = true,
  ["model"] = true,
  -- optional
  ["frequency_penalty"] = true,
  ["logit_bias"] = true,
  ["logprobs"] = true,
  ["top_logprobs"] = true,
  ["max_tokens"] = true,
  ["presence_penalty"] = true,
  ["seed"] = true,
  ["stop"] = true,
  ["stream"] = true,
  ["temperature"] = true,
  ["top_p"] = true,
  ["tools"] = true,
  ["tool_choice"] = true,
}

function OpenAI:new(endpoint, api_key)
  return setmetatable({
    endpoint = endpoint,
    api_key = api_key,
    name = "openai",
  }, self)
end

function OpenAI:set_model(_) end

function OpenAI:preprocess_payload(payload)
  -- strip whitespace from ends of content
  for _, message in ipairs(payload.messages) do
    message.content = message.content:gsub("^%s*(.-)%s*$", "%1")
  end
  return utils.filter_payload_parameters(available_api_parameters, payload)
end

function OpenAI:curl_params()
  return {
    self.endpoint,
    "-H",
    "authorization: Bearer " .. self.api_key,
  }
end

function OpenAI:verify()
  if type(self.api_key) == "table" then
    logger.error("api_key is still an unresolved command: " .. vim.inspect(self.api_key))
    return false
  elseif self.api_key and string.match(self.api_key, "%S") then
    return true
  else
    logger.error("Error with api key " .. self.name .. " " .. vim.inspect(self.api_key) .. " run :checkhealth parrot")
    return false
  end
end

function OpenAI:process(line)
  if line:match("chat%.completion%.chunk") or line:match("chat%.completion") then
    line = vim.json.decode(line)
    return line.choices[1].delta.content
  end
end

function OpenAI:check(agent)
  local model = type(agent.model) == "string" and agent.model or agent.model.model
  return available_model_set[model]
end

return OpenAI

--[[
Copyright (c) 2016 Calvin Rose
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local uv = require 'luv'
local request = require('moonmint.deps.coro-http').request
local response = require 'moonmint.response'
local setmetatable = setmetatable
local crunning = coroutine.running

local agent = {}
local agent_M_mt = {}
local agent_mt = {
    __index = agent
}

local function makeAgent(options)
    local url = options.url
    local method = options.method or 'GET'
    local params = options.params
    local headers = options.headers or {}
    local body = options.body
    return setmetatable({
        url = url,
        method = method,
        params = params,
        headers = headers,
        body = body
    }, agent_mt)
end

local function sendImpl(self, body)
    body = body or self.body
    local url = self.url
    local resHead, resBody = request(self.method, url, self.headers, body)

    local headers = {}
    for i = 1, #resHead do
        headers[i] = resHead[i]
    end

    return response {
        body = resBody,
        code = resHead.code,
        headers = headers,
        version = resHead.version or 1.1,
        config = self
    }
end

function agent:send(body)
    local thread = crunning()
    if thread and uv.loop_alive() then
        return sendImpl(self, body)
    else
        local ret
        coroutine.wrap(function()
            ret = sendImpl(self, body)
        end)()
        uv.run()
        return ret
    end
end

agent_M_mt.__call = function(_, ...)
    return makeAgent(...):send()
end

return setmetatable(agent, agent_M_mt)

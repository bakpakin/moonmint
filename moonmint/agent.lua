-- local headers = require 'moonmint.deps.headers'
local uv = require 'luv'
local httpCodec = require 'moonmint.deps.codec.http'
local connect = require('luv-coro-net').connect
local coroWrap = require 'moonmint.deps.coro-wrapper'
local setmetatable = setmetatable
local crunning = coroutine.running

local agent = {}
local agent_mt = {
    __index = agent
}

local function makeAgent(options)
    local path = options.path or '/'
    local host = options.host or '0.0.0.0'
    local port = options.port
    return setmetatable({
    	netOptions = {
			host = host,
			port = port
    	},
    	head = {
			options.method or 'GET',
			host = host,
			path = path
    	},
    	body = options.body
    }, agent_mt)
end

local function sendImpl(self, body)
    body = body or self.body
    local rawRead, rawWrite, socket = connect(self.netOptions)
    local read = coroWrap.reader(rawRead, httpCodec.decoder()) -- Unused update decoder
    local write = coroWrap.writer(rawWrite, httpCodec.encoder()) -- Unused update encoder

    write(self.head)
    write(body)
    write()

    local responseHead = read()
    local responseBody = read()
    responseHead.body = responseBody

    socket:close()

    -- TODO - Modify returned response to have use metatables.
    return responseHead
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

agent_mt.call = function(_, ...)
    return makeAgent(...):send()
end

return agent

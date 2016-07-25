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

--- The main application object.
-- @module moonmint.server

local uv = require 'luv'
local httpCodec = require 'moonmint.deps.httpCodec'
local router = require 'moonmint.router'
local httpHeaders = require 'moonmint.deps.http-headers'
local getHeaders = httpHeaders.getHeaders
local coroWrap = require 'moonmint.deps.coro-wrapper'
local wrapStream = require('moonmint.deps.stream-wrap')

local setmetatable = setmetatable
local type = type
local match = string.match
local tostring = tostring

local cp = require 'coxpcall'
local pcall, xpcall, running = cp.pcall, cp.xpcall, cp.running

local Server = {}
local Server_mt = {
    __index = Server
}

local function makeServer()
    return setmetatable({
        bindings = {},
        netServers = {},
        _router = router()
    }, Server_mt)
end

local function makeResponseHead(res)
    local head = {
        code = res.code or 200
    }
    local contentLength
    local chunked
    local headers = res.headers
    if headers then
        for i = 1, #headers do
            local header = headers[i]
            local key, value = tostring(header[1]), tostring(header[2])
            key = key:lower()
            if key == "content-length" then
                contentLength = value
            elseif key == "content-encoding" and value:lower() == "chunked" then
                chunked = true
            end
            head[#head + 1] = headers[i]
        end
    end
    local body = res.body
    if type(body) == "string" then
        if not chunked and not contentLength then
            head[#head + 1] = {"Content-Length", #body}
        end
    end
    return head
end

local function onConnect(self, binding, socket)
    local rawRead, rawWrite, close = wrapStream(socket)
    local read, updateDecoder = coroWrap.reader(rawRead, httpCodec.decoder())
    local write, updateEncoder = coroWrap.writer(rawWrite, httpCodec.encoder())
    while true do
        local head = read()
        if type(head) ~= 'table' then
            break
        end
        local url = head.path or ""
        local path, rawQuery = match(url, "^([^%?]*)[%?]?(.*)$")
        local req = {
            app = self,
            socket = socket,
            method = head.method,
            url = url,
            path = path,
            originalPath = path,
            rawQuery = rawQuery,
            binding = binding,
            read = read,
            close = close,
            headers = getHeaders(head),
            version = head.version,
            keepAlive = head.keepAlive
        }
        local res = self._router:doRoute(req)
        if type(res) ~= 'table' then
            break
        end
        -- Write response
        write(makeResponseHead(res))
        local body = res.body
        write(body and tostring(body) or nil)
        write()
        -- Drop non-keepalive and unhandled requets
        if not (res.keepAlive and head.keepAlive) then
            break
        end
        -- Handle upgrade requests
        if res.upgrade then
            res.upgrade(read, write, updateDecoder, updateEncoder, socket)
            break
        end
    end
    return close()
end

function Server:bind(options)
    options = options or {}
    if not options.host then
        options.host = '0.0.0.0'
    end
    if not options.port then
        options.port = uv.getuid() == 0 and
        (options.tls and 443 or 80) or
        (options.tls and 8443 or 8080)
    end
    self.bindings[#self.bindings + 1] = options
    return self
end

function Server:close()
    local netServers = self.netServers
    for i = 1, #netServers do
        local s = netServers[i]
        s:close()
    end
end

local function addOnStart(fn, a, b)
    if fn then
        local timer = uv.new_timer()
        timer:start(0, 0, coroutine.wrap(function()
            timer:close()
            return fn(a, b)
        end))
    end
end

function Server:startLater(options)
    if not options then
        options = {}
    end
    local bindings = self.bindings
    if #bindings < 1 then
        self:bind()
    end
    for i = 1, #bindings do
        local binding = bindings[i]
        local tls = binding.tls or options.tls
        local socketWrap
        if tls then
            local secureSocket = require('moonmint.deps.secure-socket')
            socketWrap = function(x) return assert(secureSocket(x, tls)) end
        else
            socketWrap = function(x) return x end
        end
        local server = uv.new_tcp()
        table.insert(self.netServers, server)
        assert(server:bind(binding.host, binding.port))
        assert(server:listen(256, function(err)
            assert(not err, err)
            local socket = uv.new_tcp()
            server:accept(socket)
            coroutine.wrap(function()
                local success, fail = pcall(function()
                    return onConnect(self, binding, socketWrap(socket))
                end)
                if not success then
                    print(fail)
                end
            end)()
        end))
        addOnStart(binding.onStart, self, binding)
    end
    addOnStart(options.onStart, self)
    return self
end

function Server:start(options)
    self:startLater(options)
    uv.run()
    return self
end

-- Duplicate router functions for the server, so routes and middleware can be placed
-- directly on the server.
local function alias(fname)
    Server[fname] = function(self, ...)
        local r = self._router
        r[fname](r, ...)
        return self
    end
end

alias("use")
alias("route")
alias("all")

-- HTTP version 1.1
alias('get')
alias('put')
alias('post')
alias('delete')
alias('head')
alias('options')
alias('trace')
alias('connect')

-- WebDAV
alias('bcopy')
alias('bdelete')
alias('bmove')
alias('bpropfind')
alias('bproppatch')
alias('copy')
alias('lock')
alias('mkcol')
alias('move')
alias('notify')
alias('poll')
alias('propfind')
alias('search')
alias('subscribe')
alias('unlock')
alias('unsubscribe')

return makeServer

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
local createServer = require('moonmint.deps.coro-net').createServer
local httpCodec = require 'moonmint.deps.httpCodec'
local router = require 'moonmint.router'
local httpHeaders = require 'moonmint.deps.http-headers'
local getHeaders = httpHeaders.getHeaders
local response = require 'moonmint.response'
local coroWrap = require 'moonmint.deps.coro-wrapper'

local setmetatable = setmetatable
local type = type
local pcall = pcall
local match = string.match

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

local function onConnect(self, binding, rawRead, rawWrite, socket)
    local read, updateDecoder = coroWrap.reader(rawRead, httpCodec.decoder())
    local write, updateEncoder = coroWrap.writer(rawWrite, httpCodec.encoder())
    for head in read do

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
            headers = getHeaders(head),
            version = head.version,
            keepAlive = head.keepAlive
        }

        -- Catch errors
        local status, res = pcall(self._router.doRoute, self._router, req)
        if not status then
            status, res = pcall(binding.errorHandler, res, req)
            if not status then
                socket:close()
                break
            end
        end

        -- Check response
        if not res then
            socket:close()
            break
        end
        if type(res) ~= 'table' then
            status, res = pcall(response, res)
            if not status then
                status, res = pcall(binding.errorHandler,
                'expected table as response', req)
                if not status then
                    break
                end
            end
            if not res or type(res) ~= 'table' then
                break
            end
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
            pcall(res.upgrade, read, write, updateDecoder, updateEncoder, socket)
            break
        end

    end
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

local function defaultErrorHandler(err)
    local fullError = 'Internal Sever Error:\n' .. debug.traceback(err)
    print(fullError)
    return {
        code = 500,
        body = fullError
    }
end

function Server:start(options)
    if not options then
        options = {}
    end
    local bindings = self.bindings
    if #bindings < 1 then
        self:bind(options)
    end
    for i = 1, #bindings do
        local binding = bindings[i]
        local newBinding = {
            host = binding.host,
            port = binding.port,
            onStart = binding.onStart,
            errorHandler = binding.errorHandler
        }
        local tls = binding.tls or options.tls
        if tls then
            newBinding.tls = {
                key = tls.key,
                cert = tls.cert,
                server = true
            }
        end
        local callback = function(...) return onConnect(self, newBinding, ...) end

        -- Set request error handler unless explicitely disabled
        if newBinding.errorHandler ~= false then
            if options.errorHandler ~= false then
                newBinding.errorHandler = newBinding.errorHandler or
                    options.errorHandler or
                    defaultErrorHandler
            end
        end

        -- Create server with coro-net
        table.insert(self.netServers, createServer(binding, callback))
        local onStart = binding.onStart or options.onStart
        if onStart then
            onStart(self, binding)
        end
    end
    if not options.noUVRun then
        return uv.run()
    end
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

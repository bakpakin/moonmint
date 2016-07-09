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
local createServer = require('luv-coro-net').createServer
local httpCodec = require 'moonmint.deps.codec.http'
local tlsWrap = require 'moonmint.deps.codec.tls'
local router = require 'moonmint.router'
local static = require 'moonmint.static'
local headers = require 'moonmint.deps.headers'
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
        _router = router()
    }, Server_mt)
end

local function onConnect(self, binding, rawRead, rawWrite, socket)
    local read, updateDecoder = coroWrap.reader(rawRead, httpCodec.decoder())
    local write, updateEncoder = coroWrap.writer(rawWrite, httpCodec.encoder())
    for head in read do

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
            read = read,
            headers = head,
            version = head.version,
            keepAlive = head.keepAlive
        }
        setmetatable(req.headers, headers)

        -- Catch errors
        local status, res = pcall(self._router.doRoute, self._router, req)
        if not status then
            status, res = pcall(binding.errorHandler, res, req, self, binding)
            if not status then
                return
            end
        end

        -- Check response
        if not res then
            return
        end
        if type(res) ~= 'table' then
            status, res = pcall(binding.errorHandler,
                'expected table as response', req, self, binding)
            if not status then
                return
            end
        end

        -- Write response
        write(res)
        local body = res.body
        write(body and tostring(body) or nil)
        write()

        -- Drop non-keepalive and unhandled requets
        if not (res.keepAlive and head.keepAlive) then
            return
        end

        -- Handle upgrade requests
        if res.upgrade then
            pcall(res.upgrade, read, write, updateDecoder, updateEncoder, socket)
            return
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

local function defaultErrorHandler(err)
    print('Internal Server Error:', err)
    return {
        code = 500,
        body = 'Internal Server Error'
    }
end

function Server:start(options)
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
        local callback
        if tls then
            callback = function(rawRead, rawWrite, socket)
                local newRead, newWrite = tlsWrap(rawRead, rawWrite, {
                    server = true,
                    key = assert(tls.key, "tls key required"),
                    cert = assert(tls.cert, "tls cert required"),
                })
                return onConnect(self, binding, newRead, newWrite, socket)
            end
        else
            callback = function(...) return onConnect(self, binding, ...) end
        end

        -- Set request error handler unless explicitely disabled
        if binding.errorHandler ~= false then
            if options.errorHandler~= false then
                binding.errorHandler = binding.errorHandler or
                    options.errorHandler or
                    defaultErrorHandler
            end
        end

        -- Create server with coro-net
        createServer(binding, callback)
        local onStart = binding.onStart or options.onStart
        if onStart then
            onStart(self, binding)
        end
    end
    if not options.noUVRun then
        return uv.run()
    end
end

function Server:static(urlpath, realpath)
    realpath = realpath or urlpath
    self:use(urlpath, static({
        base = realpath
    }))
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

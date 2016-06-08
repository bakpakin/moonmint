--[[
Copyright (c) 2015 Calvin Rose
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

local createServer = require('coro-net').createServer
local wrapper = require('coro-wrapper')
local readWrap, writeWrap = wrapper.reader, wrapper.writer
local httpCodec = require('http-codec')
local tlsWrap = require('coro-tls').wrap

local router = require './router'
local static = require './static'
local request = require './request'
local response = require './response'

local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset
local type = type
local select = select
local tremove = table.remove
local lower = string.lower
local pcall = pcall
local match = string.match

local uv = require('uv')
if uv.constants.SIGPIPE then
    uv.new_signal():start("sigpipe")
end

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

-- Modified from https://github.com/creationix/weblit/blob/master/libs/weblit-app.lua
function Server:handleConnection(binding, rawRead, rawWrite, socket)
    local read, updateDecoder = readWrap(rawRead, httpCodec.decoder())
    local write, updateEncoder = writeWrap(rawWrite, httpCodec.encoder())
    for head in read do

        local url = head.path or ""
        local path, rawQuery = match(url, "^([^%?]*)[%?]?(.*)$")

        local req = request {
            app = self,
            socket = socket,
            method = head.method,
            url = url,
            path = path,
            originalPath = path,
            rawQuery = rawQuery,
            read = read,
            updateDecoder = updateDecoder,
            headers = head,
            version = head.version,
            keepAlive = head.keepAlive
        }

        local res = response {
            app = self,
            write = write,
            updateEncoder = updateEncoder,
            socket = socket,
            headers = {},
            state = "pending"
        }

        -- Use middleware and catch errors.
        local status = pcall(self._router.doRoute, self, req, res)
        if not status then
            res.state = "error"
            binding.errorHandler(err, req, res, self, binding)
            return
        end

        -- Drop non-keepalive and unhandled requets
        if res.state == "pending" or 
            res.state == "error" or
            (not (res.keepAlive and head.keepAlive)) then
            break
        end

        -- Handle upgrade requests
        if res.upgrade then
            return res.upgrade(read, write, updateDecoder, updateEncoder, socket)
        end

    end
end

function Server:bind(options)
    options = options or {}
    if not options.host then
        options.host = "0.0.0.0"
    end
    if not options.port then
        options.port = require('uv').getuid() == 0 and
            (options.tls and 443 or 80) or
            (options.tls and 8443 or 8080)
    end
    self.bindings[#self.bindings + 1] = options
    return self
end

local function defaultErrorHandler(err, req, res, server, binding)
    print('Internal Server Error:', err)
    res:status(500):send('Internal Server Error')
end

local function defaultGlobalErrorHandler(err, server, binding)
    print('Uncaught Internal Server Error:', err)
end

function Server:start()
    local bindings = self.bindings
    if #bindings < 1 then
        self:bind()
    end
    for i = 1, #bindings do
        local binding = bindings[i]
        local tls = binding.tls
        local callback
        if tls then
            callback = function(rawRead, rawWrite, socket)
                local newRead, newWrite = tlsWrap(rawRead, rawWrite, {
                    server = true,
                    key = assert(tls.key, "tls key required"),
                    cert = assert(tls.cert, "tls cert required")
                })
                return self:handleConnection(binding, newRead, newWrite, socket)
            end
        else
            callback = function(...) return self:handleConnection(binding, ...) end
        end

        -- Wrap callback with an error handler to catch server errors. If the error handler
        -- is expicitely false, don't use any error handler
        local wrappedCallback = callback
        if options.globalErrorHandler ~= false then
            local gErrorHandler = options.globalErrorHandler or defaultGlobalErrorHandler
            wrappedCallback = function(...)
                local status, a, b, c, d, e, f = pcall(callback, ...)
                if not status then
                    return gErrorHandler(a, self, binding)
                end
                return a, b, c, d, e, f
            end
        end

        -- Set request error handler unless explicitely disabled
        if options.errorHandler ~= false then
            options.errorHandler = options.errorHandler or defaultErrorHandler
        end

        -- Create server with coro-net
        createServer(binding, wrappedCallback)
        if binding.onStart then
            binding.onStart(self, binding)
        end
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
local function routerWrap(fname)
    Server[fname] = function(self, ...)
        local r = self._router
        r[fname](r, ...)
        return self
    end
end

routerWrap("use")
routerWrap("route")
routerWrap("get")
routerWrap("put")
routerWrap("post")
routerWrap("delete")
routerWrap("options")
routerWrap("trace")
routerWrap("connect")
routerWrap("all")
routerWrap("head")

return makeServer

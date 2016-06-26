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

local createServer = require('luv-coro-net').createServer
local httpCodec = require 'moonmint.deps.codec.http'
local tlsWrap = require 'moonmint.deps.codec.tls'
local router = require 'moonmint.router'
local static = require 'moonmint.static'
local request = require 'moonmint.deps.request'
local response = require 'moonmint.deps.response'

local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset
local type = type
local select = select
local tremove = table.remove
local lower = string.lower
local pcall = pcall
local match = string.match

-- Pull readWrap and writeWrap from coro-wrapper
local function readWrap(read, decode)
    local buffer = ""
    return function ()
        while true do
            local item, extra = decode(buffer)
            if item then
                buffer = extra
                return item
            end
            local chunk = read()
            if not chunk then return end
            buffer = buffer .. chunk
        end
    end,
    function (newDecode)
        decode = newDecode
    end
end

local function writeWrap(write, encode)
    return function (item)
        if not item then
            return write()
        end
        return write(encode(item))
    end,
    function (newEncode)
        encode = newEncode
    end
end

-- Server implementation
local state, uv = pcall(require, 'uv')
if not state then uv = require 'luv' end
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

function Server:onConnect(binding, rawRead, rawWrite, socket)
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
            headers = head,
            version = head.version,
            keepAlive = head.keepAlive
        }

        local res = response {
            app = self,
            write = write,
            updateDecoder = updateDecoder,
            updateEncoder = updateEncoder,
            socket = socket,
            headers = {},
            state = "pending"
        }

        -- Use middleware and catch errors.
        -- Errors outside of this will not  be caught.
        local status, err = pcall(self._router.doRoute, self._router, req, res)
        if not status then
            res.state = "error"
            pcall(binding.errorHandler, err, req, res, self, binding)
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
            pcall(res.upgrade, read, write, updateDecoder, updateEncoder, socket)
            return
        end

    end
end

function Server:bind(options)
    options = options or {}
    if not options.host then
        options.host = "0.0.0.0"
    end
    if not options.port then
        options.port = uv.getuid() == 0 and
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

function Server:start(options)
    if not options then
        options = {}
    end
    -- Add bindings in options
    for i, binding in ipairs(options) do
        self.bind(binding)
    end
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
                    cert = assert(tls.cert, "tls cert required"),
                })
                return self:onConnect(binding, newRead, newWrite, socket)
            end
        else
            callback = function(...) return self:onConnect(binding, ...) end
        end

        -- Set request error handler unless explicitely disabled
        if binding.errorHandler ~= false then
            binding.errorHandler = binding.errorHandler or defaultErrorHandler
        end

        -- Create server with coro-net
        createServer(binding, callback)
        if binding.onStart then
            binding.onStart(self, binding)
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

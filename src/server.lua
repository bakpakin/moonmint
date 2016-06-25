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
local httpCodec = require 'moonmint.codec.http'
-- local tlsWrap = require 'moonmint.codec.tls'
local tlsWrap = function(a, b, c) return a, b, c end
local router = require 'moonmint.router'
local static = require 'moonmint.static'

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

-- HTTP headers meta table
local headers_mt = {
    __index = function(self, key)
        if type(key) ~= "string" then
            return rawget(self, key)
        end
        key = lower(key)
        for i = 1, #self do
            local val = rawget(self, i)
            if lower(val[1]) == key then
                return val[2]
            end
        end
    end,
    __newindex = function(self, key, value)
        if type(key) ~= "string" then
            return rawset(self, key, value)
        end
        local wasset = false
        key = lower(key)
        for i = #self, 1, -1 do
            local val = rawget(self, i)
            if lower(val[1]) == key then
                if wasset then
                    local len = #self
                    rawset(self, i, rawget(self, len))
                    rawset(self, len, nil)
                else
                    wasset = true
                    val[2] = value
                end
            end
        end
        if not wasset then
            return rawset(self, #self + 1, {key, value})
        end
    end
}

-- Request meta table
local request_index = {}
local request_mt = {__index = request_index}

function request_index:get(name)
    return self.headers[name]
end

local function request(t)
    t = t or { headers = {} }
    setmetatable(t.headers, headers_mt)
    return setmetatable(t, request_mt)
end

-- Response metatable and methods
local response_index = {}
local response_mt = {__index = response_index}

local function response(t)
    t = t or { headers = {} }
    setmetatable(t.headers, headers_mt)
    return setmetatable(t, response_mt)
end

function response_index:set(name, value)
    self.headers[name] = value;
    return self
end

function response_index:get(name)
    return self.headers[name]
end

function response_index:send(body)
    if self.state ~= "pending" then
        error(string.format("Response state is \"%s\", expected \"pending\".",  self.state))
    end

    local write = self.write
    body = body or self.body or ""
    self.headers["Content-Type"] = self.mime or 'text/html'

    -- Modify the res table in-place to conform to luvit http-codec
    self.code = self.code or 200
    rawset(self.headers, "code", self.code)
    write(self.headers);
    rawset(self.headers, "code", nil)

    -- Write the body.
    write(body)
    write()
    self.state = "done"

    return self
end

function response_index:status(code)
    self.code = code
    return self
end

function response_index:append(field, ...)
    local value
    if type(...) == 'table' then
        value = table.concat(...)
    else
        value = table.concat({...})
    end
    local prev = self.headers[field]
    if prev then
        self.headers[field] = prev .. tostring(value)
    else
        self.headers[field] = tostring(value)
    end
end

function response_index:redirect(location)
    self.code = 302
    self.headers["Location"] = location
    return self:send()
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
        local status = pcall(self._router.doRoute, self._router, req, res)
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

local function defaultGlobalErrorHandler(err, server, binding)
    print('Uncaught Internal Server Error:', err)
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
                    ca = tls.ca -- TODO - load root ca
                })
                return self:onConnect(binding, newRead, newWrite, socket)
            end
        else
            callback = function(...) return self:onConnect(binding, ...) end
        end

        -- Wrap callback with an error handler to catch server errors. If the error handler
        -- is expicitely false, don't use any error handler
        local wrappedCallback = callback
        if binding.globalErrorHandler ~= false then
            local gErrorHandler = binding.globalErrorHandler or defaultGlobalErrorHandler
            wrappedCallback = function(...)
                local status, a, b, c, d, e, f = pcall(callback, ...)
                if not status then
                    return gErrorHandler(a, self, binding)
                end
                return a, b, c, d, e, f
            end
        end

        -- Set request error handler unless explicitely disabled
        if binding.errorHandler ~= false then
            binding.errorHandler = binding.errorHandler or defaultErrorHandler
        end

        -- Create server with coro-net
        createServer(binding, wrappedCallback)
        if binding.onStart then
            binding.onStart(self, binding)
        end
    end
    if not options.noUVRun then
        uv.run()
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

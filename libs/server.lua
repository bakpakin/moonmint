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

exports.name = "bakpakin/moonmint-server"
exports.version = "0.0.1"
exports.dependencies = {
    "bakpakin/moonmint-router@0.0.1",
    "bakpakin/moonmint-static@0.0.1",
    "creationix/coro-wrapper@1.0.0",
    "creationix/coro-net@1.1.1",
    "creationix/coro-tls@1.3.1",
    "luvit/http-codec@1.0.0",
    "luvit/querystring@1.0.2",
}
exports.description = "The main server in the moonmint framework."
exports.tags = {"moonmint", "server"}
exports.license = "MIT"
exports.author = { name = "Calvin Rose" }
exports.homepage = "https://github.com/bakpakin/moonmint"

local createServer = require('coro-net').createServer
local wrapper = require('coro-wrapper')
local readWrap, writeWrap = wrapper.reader, wrapper.writer
local httpCodec = require('http-codec')
local tlsWrap = require('coro-tls').wrap
local parseQuery = require('querystring').parse

local router = require 'moonmint-router'
local static = require 'moonmint-static'
local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset
local type = type
local select = select
local tremove = table.remove
local lower = string.lower
local pcall = pcall

local uv = require('uv')
if uv.constants.SIGPIPE then
  uv.new_signal():start("sigpipe")
end

local Headers_mt = {
    __index = function(self, key)
        if type(key) ~= "string" then
            return rawget(self, key)
        end
        key = lower(key)
        for i = 1, #self, 2 do
            if self[i] == key then
                return self[i + 1]
            end
        end
    end,
    __newindex = function(self, key, value)
        if type(key) ~= "string" then
            return rawset(self, key, value)
        end
        key = lower(key)
        for i = #self - 1, 1, -2 do
            if lower(self[i]) == key then
                local len = #self
                self[i] = self[len - 1]
                self[i + 1] = self[len]
                self[len] = nil
                self[len - 1] = nil
            end
        end
        if value == nil then return end
        rawset(self, key, value)
    end
}

local Request = {}
local Request_mt = { __index = Request }

local Response = {}
local Response_mt = { __index = Response }

local function makeDefaultResponse()
    return setmetatable({
        code = 404,
        headers = setmetatable({}, Headers_mt),
        body = "404 Not Found."
    }, Response_mt)
end

function Response:send(body)
    self.code = 200
    self.body = body
end

local function reqresSetHeader(self, name, ...)
    local value = (select("#", ...) == 1) and ... or {...}
    self.headers[name] = value
    return self
end
Request.setHeader = reqresSetHeader
Response.setHeader = reqresSetHeader

local function reqresGetHeader(self, name)
    return self.header[name]
end
Request.getHeader = reqresGetHeader
Response.getHeader = reqresGetHeader


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
function Server:handleRequest(head, input, socket)
    local req = setmetatable({
        socket = socket,
        method = head.method,
        path = head.path,
        headers = setmetatable({}, Header_mt),
        version = head.version,
        keepAlive = head.keepAlive,
        body = input
    }, Request_mt)
    for i = 1, #head do
        req.headers[2 * i], req.headers[2 * i + 1] = head[i], head[i + 1]
    end
    local res = makeDefaultResponse()
    self._router:doRoute(req, res, go)
    local out = {
        code = res.code,
        keepAlive = res.keepAlive
    }
    for i = 1, #res.headers / 2 do
        out[i] = {res.headers[2 * i], res.headers[2 * i + 1]}
    end
    return out, res.body, res.upgrade
end

-- Modified from https://github.com/creationix/weblit/blob/master/libs/weblit-app.lua
function Server:handleConnection(rawRead, rawWrite, socket)
    local read, updateDecoder = readWrap(rawRead, httpCodec.decoder())
    local write, updateEncoder = writeWrap(rawWrite, httpCodec.encoder())
    for head in read do
        local parts = {}
        for chunk in read do
            if #chunk > 0 then
                parts[#parts + 1] = chunk
            else
                break
            end
        end
        local res, body, upgrade = self:handleRequest(head, #parts > 0 and table.concat(parts) or nil, socket)
        write(res)
        if upgrade then
            return upgrade(read, write, updateDecoder, updateEncoder, socket)
        end
        write(body)
        if not (res.keepAlive and head.keepAlive) then
            break
        end
    end
    write()
end

function Server:bind(options)
    if not options.host then
        options.host = "127.0.0.1"
    end
    if not options.port then
        options.port = require('uv').getuid() == 0 and
            (options.tls and 443 or 80) or
            (options.tls and 8443 or 8080)
    end
    self.bindings[#self.bindings + 1] = options
    return self
end

function Server:start()
    local bindings = self.bindings
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
                return self:handleConnection(newRead, newWrite, socket)
            end
        else
            callback = function(...) return self:handleConnection(...) end
        end
        createServer(binding, callback)
        print(("HTTP server listening at http%s://%s:%d..."):format(binding.tls and "s" or "", binding.host, binding.port))
    end
end

function Server:static(urlpath, realpath)
    realpath = realpath or urlpath
    self._router:use(urlpath, static(realpath))
    return self
end

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
routerWrap("all")
routerWrap("head")

return makeServer

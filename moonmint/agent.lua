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

-- Connection and Request code modified from
-- https://github.com/luvit/lit/blob/master/deps/coro-http.lua

--- @classmod Agent
--
-- The Agent class is used to make HTTP requests.
-- Query APIs on a server or make your own HTTP client.
--
-- @author Calvin Rose
-- @license MIT
-- @copyright 2016
--

local uv = require 'luv'
local response = require 'moonmint.response'
local httpHeaders = require 'moonmint.deps.http-headers'
local url = require 'moonmint.url'
local pathJoin = require 'moonmint.deps.pathjoin'.pathJoin
local httpCodec = require 'moonmint.deps.httpCodec'
local net = require 'moonmint.deps.coro-net'
local setmetatable = setmetatable
local crunning = coroutine.running
local match = string.match

local connections = {}

local function clearConnections()
    for i = 1, #connections do
        local connection = connections[i]
        if not connection.socket:is_closing() then
            connection.socket:close()
        end
    end
    connections = {}
end

local function getConnection(host, port, tls)
    for i = #connections, 1, -1 do
        local connection = connections[i]
        if connection.host == host and connection.port == port and connection.tls == tls then
            table.remove(connections, i)
            -- make sure the connection is still alive before reusing it.
            if not connection.socket:is_closing() then
                connection.reused = true
                connection.socket:ref()
                return connection
            end
        end
    end
    local read, write, socket, updateDecoder, updateEncoder = assert(net.connect {
        host = host,
        port = port,
        tls = tls,
        encode = httpCodec.encoder(),
        decode = httpCodec.decoder()
    })
    return {
        socket = socket,
        host = host,
        port = port,
        tls = tls,
        read = read,
        write = write,
        updateEncoder = updateEncoder,
        updateDecoder = updateDecoder,
        reset = function ()
            -- This is called after parsing the response head from a HEAD request.
            -- If you forget, the codec might hang waiting for a body that doesn't exist.
            updateDecoder(httpCodec.decoder())
        end
    }
end

local function saveConnection(connection)
    if connection.socket:is_closing() then return end
    connections[#connections + 1] = connection
    connection.socket:unref()
end

local function makeHead(self, host, path, body)
    -- Use GET as default method
    local method = self:getConf('method') or 'GET'
    local head = {
        method = method,
        path = path,
        {"Host", host}
    }
    local contentLength
    local chunked
    local headers = self.headers
    if headers then
        for i = 1, #headers do
            local key, value = unpack(headers[i])
            key = key:lower()
            if key == "content-length" then
                contentLength = value
            elseif key == "content-encoding" and value:lower() == "chunked" then
                chunked = true
            end
            head[#head + 1] = headers[i]
        end
    end
    if type(body) == "string" then
        if not chunked and not contentLength then
            head[#head + 1] = {"Content-Length", #body}
        end
    end
    return head
end

local function requestImpl(self, tls, hostname, port, head, body)
    -- Get a connection
    local connection = getConnection(hostname, port, tls)
    local read = connection.read
    local write = connection.write

    write(head)
    if body then write(body) end
    local res = read()
    if not res then
        if not connection.socket:is_closing() then
            connection.socket:close()
        end
        -- If we get an immediate close on a reused socket, try again with a new socket.
        -- TODO: think about if this could resend requests with side effects and cause
        -- them to double execute in the remote server.
        if connection.reused then
            return requestImpl(self, tls, hostname, port, head, body)
        end
        error("connection closed")
    end

    body = {}
    if head.method == "HEAD" then
        connection.reset()
    else
        while true do
            local item = read()
            if not item then
                res.keepAlive = false
                break
            end
            if #item == 0 then
                break
            end
            body[#body + 1] = item
        end
    end

    if res.keepAlive then
        saveConnection(connection)
    else
        write()
    end

    -- Follow redirects
    if not self:getConf('noFollow') and
        head.method == "GET" and
        (res.code == 302 or res.code == 307) then
        for i = 1, #res do
            local key, location = unpack(res[i])
            if key:lower() == "location" then
                head.path = location
                return requestImpl(self, tls, hostname, port, head, body)
            end
        end
    end

    return res, table.concat(body)
end

local function sendImpl(self, body)
    body = body or self:getConf('body')
    local uri = self:getConf('url')
    local proto = match(uri, '^https?://')
    if proto then
        uri = uri:sub(#proto + 1)
    end
    local hostname, path = match(uri, '^([%w%:%.%-]*)(.-)$')
    hostname, path = hostname or '', path or ''

    -- Make path
    local selfPath = self:getConf('path')
    if selfPath then
        path = pathJoin(path, selfPath)
    end
    if path == '' then
        path = '/'
    end
    local alreadyHasQuery = match(path, '%?')
    local rawQuery = url.queryEncode(self.params)
    if rawQuery ~= '' then
        path = path .. (alreadyHasQuery and '&' or '?') .. rawQuery
    end

    -- Get port, host, and protocol
    local tls = proto == 'https://'
    local host, port = match(hostname, '^([^:]+):?(%d*)$')
    if port == '' then
        port = tls and 443 or 80
    else
        port = tonumber(port) or 80
    end

    -- Resolve localhost
    if host == '' or host == 'localhost' or not host then
        host = '127.0.0.1'
    end

    local head = makeHead(self, host, path, body)
    local resHead, resBody = requestImpl(self, tls, host, port, head, body)

    return response {
        body = resBody,
        code = resHead.code,
        headers = httpHeaders.getHeaders(resHead),
        version = resHead.version or 1.1,
        config = self
    }
end

local Agent = {}

--- Configure a key value pair on the Agent
--@param key
--@param value
-- @return self
function Agent:conf(key, value)
    self.config[key] = value
    return self
end

--- Get a configured option on the Agent
-- @param key
-- @return the value
function Agent:getConf(key)
    return self.config[key]
end

--- Set the body of the Agent.
-- @param body the body of the agent
-- @return self
function Agent:body(body)
    return self:conf('body', body)
end

--- Send a request with the Agent, with an optional body.
-- @param body the (optional) body of the request
-- @return self
function Agent:send(body)
    local thread = crunning()
    if thread then
        return sendImpl(self, body)
    else
        local ret
        local loop = true
        coroutine.wrap(function()
            ret = sendImpl(self, body)
            loop = false
        end)()
        while loop do
            uv.run('once')
        end
        return ret
    end
end

function Agent:sendcb(body, cb)
    if not cb then
        cb = body
        body = nil
    end
    return coroutine.wrap(function()
        local status, err = pcall(sendImpl, self, body)
        if status then
            return cb(nil, err)
        else
            return cb(err)
        end
    end)()
end

--- Set a header to a certain value. Headers are case-insensitive.
-- @param header the Header to set
-- @param value the value of the header
-- @return self
function Agent:set(header, value)
    self.headers[header] = value
    return self
end

--- Sets a query parameter. The value should be a string.
-- @param key the name of the parameter
-- @param value the value of the parameter
-- @return self
function Agent:param(key, value)
    self.params[key] = value or true
    return self
end

--- Sets the url of the Agent. Can either just the url host, path, pr a combination of both.
-- @param uri
-- @return self
function Agent:url(uri)
    if match(uri, '^[a-z]+://') then
        return self:conf('url', uri)
    else
        return self:conf('path', uri)
    end
end

function Agent:pathjoin(path)
    if match(path, '^[a-z]+://') then
        return self:conf('url', path)
    else
        local oldPath = self:getConf('path')
        if oldPath then
            return self:conf('path', pathJoin(oldPath, path))
        else
            return self:conf('path', path)
        end
    end
end

--- Sets the HTTP method of the request.
-- @param method
-- @return self
function Agent:method(method)
    return self:conf('method', tostring(method):upper())
end

function Agent:get(uri)
    return self:method('GET'):url(uri)
end

function Agent:delete(uri)
    return self:method('DELETE'):url(uri)
end
Agent.del = Agent.delete

function Agent:put(uri)
    return self:method('PUT'):url(uri)
end

function Agent:post(uri)
    return self:method('POST'):url(uri)
end

-- Just some useful shortcuts
-- TODO Add more
local acceptMappings = {
    json = 'application/json',
    text = 'text/*',
    html = 'text/html',
    js = 'text/javascript',
    xml = 'text/xml',
    css = 'text/css',
    all = '*/*'
}

local typeMappings = {
    text = 'text/plain'
}

function Agent:accept(...)
    local currentlyAccepts = self.headers.Accept or ''
    if not match(currentlyAccepts, ';%s*$') then
        currentlyAccepts = currentlyAccepts .. '; '
    end
    local toAccept = {}
    for i = 1, select('#', ...) do
        local tp = select(i, ...)
        toAccept[#toAccept + 1] = acceptMappings[tp] or tp
    end
    self.headers.Accept = currentlyAccepts .. table.concat(toAccept, '; ')
    return self
end

--- Sets the content type of the Agent.
-- @param tp the content type. Can be a full mime type or a short alias, like 'json'
-- @return self
function Agent:type(tp)
    self.headers['Content-Type'] = typeMappings[tp] or acceptMappings[tp] or tp
    return self
end

--- Creates a module out of an Agent. The module behaves
-- the same as the original Agent, but creates a copy
-- of the original Agent on all methods. This is very
-- useful for creating interfaces to APIs, or otherwise
-- reusing complex Agent configurations with modifications.
-- @return a new module
function Agent:module()
    local newModule = {}
    return setmetatable(newModule, {
        __index = function(child, key)
            local value = rawget(child, key)
            if value ~= nil then
                return value
            end
            value = self[key]
            if type(value) == 'function' then
                local method = function(self1, ...)
                    if self1 == newModule then
                        local new = self()
                        return new[key](new, ...)
                    else
                        return value(self1, ...)
                    end
                end
                child[key] = method
                return method
            end
            return value
        end
    })
end

local function makeRequest(parent)
    local params = {}
    if parent and parent.params then
        for k, v in pairs(parent.params) do
            params[k] = v
        end
    end
    return setmetatable({
        params = params,
        config = setmetatable({}, {
            __index = parent.config
        })
    }, {
        __index = parent,
        __call = makeRequest
    })
end

local M = {}

for k, v in pairs(Agent) do
    M[k] = function(self, ...)
        if self == M then
            return v(makeRequest(Agent), ...)
        else
            return v(makeRequest(Agent), self, ...)
        end
    end
end

function M:close()
    clearConnections()
end

return M

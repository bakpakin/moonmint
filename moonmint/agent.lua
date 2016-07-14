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

local function getConnection(host, port, tls)
    for i = #connections, 1, -1 do
        local connection = connections[i]
        if connection.host == host and connection.port == port and connection.tls == tls then
            table.remove(connections, i)
            -- Make sure the connection is still alive before reusing it.
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
    local method = self.method or 'GET'
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
    if not self.config.noFollow and
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
    body = body or self.body
    local uri = self.url
    local proto, hostname, path = match(uri, '^([a-z]*).-([%w%.%-]+)(.*)$')

    -- Make path
    if self.path then
        path = pathJoin(path, self.path)
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
    local tls = proto == 'https'
    local host, port = match(hostname, '^([^:]+):?(%d-)$')
    if port == '' then
        port = tls and 443 or 80
    else
        port = tonumber(port)
    end

    local head = makeHead(self, host, path, body)
    local resHead, resBody = requestImpl(self, tls, hostname, port, head, body)

    return response {
        body = resBody,
        code = resHead.code,
        headers = httpHeaders.getHeaders(resHead),
        version = resHead.version or 1.1,
        config = self
    }
end

local request = {}

function request:conf(key, value)
    self.config[key] = value
    return self
end

function request:send(options, body)
    if type(options) == 'table' then
        self = self:options(options)
    else
        body = options
    end
    local thread = crunning()
    if thread and uv.loop_alive() then
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

function request:options(options)
    if not options then
        return self
    end
    self.url = options.url or self.url
    self.path = options.path or self.path
    self.headers = httpHeaders.combineHeaders(self.headers,
        httpHeaders.newHeaders(options.headers))
    self.method = options.method or self.method
    self.noFollow = options.noFollow or self.noFollow
    if options.params then
        for k, v in pairs(options.params) do
            self.params[k] = v
        end
    end
    return self
end

function request:set(header, value)
    self.headers[header] = value
    return self
end

function request:param(key, value)
    self.params[key] = value
    return self
end

function request:uri(uri)
    if match(uri, '^[a-z]+://') then
        self.url = uri
    else
        self.path = uri
    end
    return self
end

function request:get(uri)
    self.method = 'GET'
    return self:uri(uri)
end

function request:delete(uri)
    self.method = 'DELETE'
    return self:uri(uri)
end
request.del = request.delete

function request:put(uri)
    self.method = 'PUT'
    return self:uri(uri)
end

function request:post(uri)
    self.method = 'POST'
    return self:uri(uri)
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

function request:accept(...)
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

for k, v in pairs(request) do
    M[k] = function(_, ...)
        return v(makeRequest(request), ...)
    end
end

return M

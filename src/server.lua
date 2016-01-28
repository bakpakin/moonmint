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
        local body = #parts > 0 and table.concat(parts) or nil
        local req = request.new {
            app = self,
            socket = socket,
            method = head.method,
            path = head.path or "",
            headers = head,
            version = head.version,
            keepAlive = head.keepAlive,
            body = body
        }
        local res = response.new {
            app = self,
            socket = socket,
            code = 404,
            headers = {},
            body = "404 Not Found.",
            done = false
        }
        -- Use middleware
        self._router:doRoute(req, res)

        -- Modify the res table in-place to conform to luvit http-codec
        rawset(res.headers, "code", res.code)
        write(res.headers)
        rawset(res.headers, "code", nil)

        if res.upgrade then
            return res.upgrade(read, write, updateDecoder, updateEncoder, socket)
        end

        write(res.body)

        if not (res.keepAlive and head.keepAlive) then
            break
        end
    end
    write()
end

function Server:bind(options)
    options = options or {}
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
    self:use(urlpath, static(realpath))
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

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

local http = require 'http'
local router = require './router'
local static = require './static'
local util = require './util'
local setmetatable = setmetatable

local server = setmetatable({}, {
    __call = function(self, ...)
        return self.new(...)
    end
})

local server_mt = {__index = server}

local request_mt = {__index = {

}}

local repsonse_mt = {__index = {

}}

local wrapHttpCallback
do
    local ccreate = coroutine.create
    local cresume = coroutine.resume
    function wrapHttpCallback(cb)
        return function(req, res)
            local newReq = setmetatable({
                method = req.method,
                headers = req.headers,
                url = req.url,
                host = req.host,
                body = req.body
            }, request_mt)
            local newRes = setmetatable({
                code = 404,
                body = "<body>Not found.</body>",
                mime =  "text/html",
                headers = res.headers
            }, response_mt)
            local cr = ccreate(function()
                cb(newReq, newRes)
                local body = newRes.body
                res.statusCode = newRes.code
                res:setHeader("Content-Type", newRes.mime)
                res:setHeader("Content-Length", #body)
                res:finish(body)
            end)
            req:on('data', function(data)
                newReq.body = data
            end)
            req:on('end', function()
                cresume(cr)
            end)
        end
    end
end

function server.new()
    local r = router()
    local wrappedCb = wrapHttpCallback(r)
    return setmetatable({
        _router = r,
        _httpServer = http.createServer(wrappedCb)
    }, server_mt):use(util.middleware.logger)
end

function server:listen(...)
    self._httpServer:listen(...)
    print('Server running on port ' .. ... .. "...")
end
server.start = server.listen

function server:static(urlpath, realpath)
    realpath = realpath or urlpath
    self._router:use(urlpath, static(realpath))
    return self
end

local function routerWrap(fname)
    server[fname] = function(self, ...)
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

return server

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

local mime = require('mimetypes').guess
local headersMeta = require 'moonmint.headers'
local response = require 'moonmint.response'
local pathJoin = require 'moonmint.deps.pathjoin'
local fs = require 'moonmint.fs'
local setmetatable = setmetatable

local Static = {}
local Static_mt = {
    __index = Static
}

function Static:_notFound(_, go)
    if self.fallthrough then
        return go()
    else
        return response('Not Found', 404)
    end
end

function Static:renderFile(req, go, path)
    local body = self.fs.readFile(path)
    if not body then return self:_notFound(req, go) end
    local mimetype = mime(path)
    return {
        code = 200,
        headers = setmetatable({
            {'Content-Length', #body},
            {'Content-Type', mimetype}
        }, headersMeta),
        body = body
    }
end

function Static:renderDirectory(req, go, path)
    local ri = self.renderIndex
    if type(ri) == 'table' then
        for i = 1, #ri do
            local testIndex = pathJoin(path, ri[i])
            local stat = self.fs.stat(testIndex);
            if stat and stat.type ~= 'directory' then
                return self:renderFile(req, go, testIndex)
            end
        end
        return self:_notFound(req, go)
    else
        return self:renderFile(req, go, pathJoin(path, ri))
    end
end

function Static:doRoute(req, go)
    if req.method ~= "GET" then return go() end
    local path = "." .. req.path
    local stat = self.fs.stat(path)
    if not stat then
        return self:_notFound(req, go)
    end
    if stat.type == "directory" then
        if self.renderIndex then
            return self:renderDirectory(req, go, path)
        else
            return self:_notFound(req, go)
        end
    else
        return self:renderFile(req, go, path)
    end
end

Static_mt.__call = Static.doRoute

return function(options)
    if type(options) == 'string' then
        options = {
            base = options
        }
    end
    options = options or {}
    local base = options.base or '.'
    local fallthrough = true
    if options.fallthrough ~= nil then
        fallthrough = options.fallthrough
    end
    local renderIndex = 'index.html'
    if options.renderIndex ~= nil and
        options.renderIndex ~= true then
        renderIndex = options.renderIndex
    end
    return setmetatable({
        fs = fs.chroot(base),
        fallthrough = fallthrough,
        renderIndex = renderIndex
    }, Static_mt)
end

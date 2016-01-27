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

exports.name = "bakpakin/moonmint-static"
exports.version = "0.0.1-1"
exports.dependencies = {
    "creationix/mime@0.1.2",
    "creationix/hybrid-fs@0.1.1",
}
exports.description = "Static file servinging middleware for the moonmint framework."
exports.tags = {"moonmint", "middleware", "static"}
exports.author = { name = "Calvin Rose" }
exports.homepage = "https://github.com/bakpakin/moonmint"

local mime = require('mime').getType
local hybridfs = require 'hybrid-fs'
local byte = string.byte
local setmetatable = setmetatable

local function makeCacheEntry(fs, path, stat)
    local body = fs.readFile(path)
    if not body then return nil end
    return {
        path = path,
        mime = mime(path),
        body = body,
        time = stat.mtime
    }
end

local Static = {}
local Static_mt = {
    __index = Static
}

function Static:doRoute(req, res, go)

    if req.method ~= "GET" then return go() end
    local path = match(req.path, "^[^?#]*")
    if byte(path) == 47 then
        path = path:sub(2)
    end

    local fs = self.fs
    local cache = self.cache
    local nocache = self.nocache

    local stat = fs.stat(path)
    if not stat then return go() end

    if stat.type == "directory" then
        if byte(path, -1) == 47 then
            path = path .. "index.html"
        else
            path = path .. "/index.html"
        end
        stat = fs.stat(path);
        if not stat then return go() end
    end

    local cachedResponse = cache[path]

    if cachedResponse and cachedResponse.time == stat.mtime then
        res.code = 200
        res.body = cachedResponse.body
        res.mime = cachedResponse.mime
    else
        cachedResponse = makeCacheEntry(path)
        if not cachedResponse then
            if go then
                return go()
            end
        end
        if not nocache then cache[path] = cachedResponse end
        res.code = 200
        res.body = cachedResponse.body
        res.mime = cachedResponse.mime
    end

end

Static_mt.__call = Static.doRoute

function Static:clearCache()
    self.cache = {}
end

return function(base, nocache)
    return setmetatable({
        fs = hybridfs(base),
        cache = {},
        nocache = nocache
    }, Static_mt)
end

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
local corofs = require 'luv-coro-fs'
local byte = string.byte
local setmetatable = setmetatable
local match = string.match

local function makeCacheEntry(fs, path, stat)
    local body = fs.readFile(path)
    if not body then return nil end
    local mime = mime(path)
    return {
        path = path,
        mime = mime,
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
    local path = "." .. req.path

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
        cachedResponse = makeCacheEntry(fs, path, stat)
        if not cachedResponse then
            return go()
        end
        if not nocache then cache[path] = cachedResponse end
        res.code = 200
        res.body = cachedResponse.body
        res.mime = cachedResponse.mime
    end
    return res:send()
end

Static_mt.__call = Static.doRoute

function Static:clearCache()
    self.cache = {}
end

return function(options)
    options = options or {}
    local base = options.base or '.'
    return setmetatable({
        fs = corofs.chroot(base),
        cache = {},
        nocache = options.nocache
    }, Static_mt)
end

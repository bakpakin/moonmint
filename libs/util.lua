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

local util = {}

local middleware = {}
util.middleware = middleware

do
    local json = require 'json'
    local errorjson = json.encode{
        error = "Data passed incorrectly. Expected JSON object."
    }
    function middleware.jsonBody(req, res, go)
        if not req.body then
            return go()
        end
        local data = json.decode(req.body, 1)
        if not data then
            res.code = 200
            res.body = errorjson
            return
        end
        req.json = data
        go()
        res.body = json.encode(res.body)
        res.mime = "application/json"
    end
end

function middleware.cookie(req, res, go)
    local cookie = req.headers["Cookie"]
    if cookie then
        local c = {}
        for part in cookie:gmatch("[^%;]+") do
            local k, v = part:match("^%s*([^%=]*)%s*=%s*([^%=]*)%s*$")
            if not k then
                k = part:match("^%s*([^%=]*)%s*$")
                if k then
                    c[k] = true
                end
            else
                c[k] = (#v > 0) and v or true
            end
        end
        req.cookie = c
    end
    return go()
end

do
    local match = string.match
    function middleware.query(req, res, go)
        local url, qstr = match(req.url, "$(.+)%?(.*)^")
        if not qstr then return go() end
        qstr = util.urlDecode(qstr)
        local query = {}
        for part in qstr:gmatch("[^%&]+") do
            local k, v = match(part, "([^=]+)=([^=]+)")
            query[k] = v
        end
        req.url = url
        req.query = query
        return go()
    end
end

do
    local date = os.date
    function middleware.logger(req, res, go)
        print(("%s: %s %s"):format(
            date(),
            req.method:upper(),
            req.url
        ))
        return go()
    end
end

do
    local match = string.match
    local byte = string.byte
    local gsub = string.gsub
    local floor = math.floor
    local char = string.char
    local specials = "[^A-Za-z0-9%*%-%.%_% ]"
    local upper = string.upper

    local digits = {
        [0] = "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"
    }

    local function getHexCode(c)
        local b = byte(c)
        if b == 32 then return "+" end
        local d1 = floor(b / 16)
        return  "%" .. digits[d1] .. digits[b - 16 * d1]
    end

    local codes = {}

    for i = 0, 255 do
        local c = char(i)
        if match(c, specials) then
            codes[c] = getHexCode(c)
        end
    end

    function util.urlEncode(str)
        local ret = gsub(str, specials, codes)
        return ret
    end

    local reverse_codes = {}

    for k, v in pairs(codes) do
        reverse_codes[v] = k
    end

    local function decodeFilter(c)
        c = upper(c)
        return reverse_codes[c]
    end

    function util.urlDecode(str)
        local ret = gsub(str, "%%[0-9a-fA-F][0-9a-fA-F]", decodeFilter)
        return ret
    end
end

do
    local running = coroutine.running
    local resume =  coroutine.resume
    local assert = assert
    function util.makeAsyncCallback()
        local thread = running()
        return function(err, value, ...)
            if err then
                return assert(resume(thread, nil, err))
            else
                return assert(resume(thread, value or true, ...))
            end
        end
    end
end


return util

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
local fs = require 'moonmint.fs'
local headersMeta = require 'moonmint.headers'
local setmetatable = setmetatable
local tonumber = tonumber

-- For coercing responses into tables
local toResponse = {
    ['string'] = function(res, code, mime)
        return {
            code = code and tonumber(code) or 200,
            headers = setmetatable({
                {'Content-Length', #res},
                {'Content-Type', mime or 'text/html'}
            }, headersMeta),
            body = res
        }
    end,
    ['number'] = function(res)
        return {
            code = res,
            headers = setmetatable({}, headersMeta)
        }
    end,
    ['table'] = function (res)
        res.headers = res.headers or {}
        setmetatable(res.headers, headersMeta)
        return res
    end
}

-- Coerce response into a table
local function responsify(...)
    local converter = toResponse[type(...)]
    if converter then
        return converter(...)
    else
        error('unable to create response from "' .. type(...) .. '"')
    end
end

local function normalizer(req, go)
    return responsify(go())
end

local function file(path)
    local body, err = fs.readFile(path)
    if not body then
        error(err)
    end
    local mime = mime(path)
    return {
        code = 200,
        headers = setmetatable({
            {'Content-Length', #body},
            {'Content-Type', mime}
        }, headersMeta),
        body = body
    }
end

function redirect(location)
    return {
        code = 302,
        headers = setmetatable({
            {'Location', location},
        }, headersMeta)
    }
end

return setmetatable({
    file = file,
    normalizer = normalizer,
    redirect = redirect,
    create = responsify
}, {
    __call = function(self, ...)
        return responsify(...)
    end
})

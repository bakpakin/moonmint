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

--- Various utility functions and middleware.
-- @module moonmint.util
-- @author Calvin Rose
-- @copyright 2016

local uv = require 'luv'
local format = string.format
local concat = table.concat
local coxpcall = require 'coxpcall'
local pcall = coxpcall.pcall
local queryDecode = require('moonmint.url').queryDecode

local util = {}

--- A middleware for getting the body of an HTTP request.
-- The body is a string placed in req.body.
function util.bodyParser(req, go)
    local parts = {}
    local read = req.read
    for chunk in read do
        if #chunk > 0 then
            parts[#parts + 1] = chunk
        else
            break
        end
    end
    req.body = #parts > 0 and concat(parts) or nil
    return go()
end

--- Simple logger middleware.
-- Logs in the format 'time | method | path | return status'.
function util.logger(req, go)
    local time = os.date()
    local res = go()
    local status = pcall(
        print,
        format("%s | %s | %s | %s",
            time,
            req.method,
            req.path,
            res and (res.code or 200) or 'No Response'))
    if not status then
        print 'Could not log response.'
    end
    return res
end

--- A middleware for parsing queries on requests.
-- Places the queries in req.query.
function util.queryParser(req, go)
    req.query = queryDecode(req.rawQuery or "")
    return go()
end

local unpack = unpack or table.unpack
local cwrap = coroutine.wrap

--- Calls a coroutine function that is asynchronous with libuv
-- and makes it blocking
function util.callSync(fn, ...)
    local ret
    local loop = true
    cwrap(function(...)
        ret = {fn(...)}
        loop = false
    end)(...)
    while loop do
        uv.run('once')
    end
    return unpack(ret)
end

function util.wrapSync(fn)
    return function(...)
        return util.callSync(fn, ...)
    end
end

return util

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

local byte = string.byte
local sub = string.sub
local tonumber = tonumber
local concat = table.concat
local assert = assert
local insert = table.insert
local type = type
local pairs = pairs

local function skipWhitespace(str, i)
    while i <= #str do
        local b = byte(str, i)
        if b == 32 or (b >= 9 and b <= 13) then
            i = i + 1
        else
            return i
        end
    end
    return i
end

local function skipWhitespaceBack(str, i)
    while i > 0 do
        local b = byte(str, i)
        if b == 32 or (b >= 9 and b <= 13) then
            i = i - 1
        else
            return i
        end
    end
    return i
end

local function getNext(str, i)
    while i <= #str do
        local b = byte(str, i)
        if b == 59 or b == 61 then
            return i, b
        end
        i = i + 1
    end
    return i
end

local function coerceString(str)
    if str == 'true' then return true end
    if str == 'false' then return false end
    local maybeNumber = tonumber(str)
    if maybeNumber then return maybeNumber end
    return str
end

local function readKVPair(str, i)
    i = skipWhitespace(str, i)
    local kStart, charCheck = i
    i, charCheck = getNext(str, i)
    local kEnd = skipWhitespaceBack(str, i - 1)
    local key = sub(str, kStart, kEnd)
    if charCheck == 61 then -- = sign
        local vStart = skipWhitespace(str, i + 1)
        i, charCheck = getNext(str, vStart)
        local vEnd = skipWhitespaceBack(str, i - 1)
        local value = sub(str, vStart, vEnd)
        return i + 1, key, value
    else -- no =, just ends
        print 'fack'
        return i + 1, key
    end
end

local function parseCookie(str)
    local ret = {}
    local i, len = 1, #str
    local kString, vString
    while i <= len do
        i, kString, vString = readKVPair(str, i)
        if vString then
            ret[coerceString(kString)] = coerceString(vString)
        else
            ret[''] = coerceString(kString)
        end
    end
    return ret
end

local inspect = require('inspect')
print(inspect(parseCookie ' key = value '))

local function makeSetCookie(options)
    assert(cookie.value, 'Expected cookie value.')
    local str = (cookie.key and (cookie.key .. '=') or '') .. cookie.value
        .. (cookie.expires and '; Expires=' .. cookie.expires or '')
        .. (cookie.maxAge and '; Max-Age=' .. cookie.max_age or '')
        .. (cookie.domain and '; Domain=' .. cookie.domain or '')
        .. (cookie.path and '; Path=' .. cookie.path or '')
        .. (cookie.secure and '; Secure' or '')
        .. (cookie.httpOnly and '; HttpOnly' or '')
        .. (cookie.sameSite and '; SameSite=' .. cookie.sameSite or '')
        .. (cookie.extension and '; ' .. cookie.extension or '')
    return str
end

local function middleware(options)
    options = options or {}
    local optionsVector = {}
    for k, v in pairs(options) do
        optionsVector[#optionsVector + 1] = k
        optionsVector[#optionsVector + 1] = v
    end
    return function(req, go)
        local cookieHeader = req.headers['cookie']
        if cookieHeader then
            req.cookies = parseCookie(cookieHeader)
        else
            req.cookies = {}
        end
        local res = go()
        local resCookies = res.cookies
        if resCookies then
            for k, v in pairs(resCookies) do
                local theOptions = {
                    key = k
                }
                for i = 1, #optionsVector, 2 do
                    theOptions[optionsVector[i]] = optionsVector[i + 1]
                end
                if type(v) == 'table' then
                    for optionKey, optionValue in pairs(v) do
                        theOptions[optionKey] = optionValue
                    end
                else
                    theOptions.value = v
                end
                insert(res.headers, {'Set-Cookie', makeSetCookie(theOptions)})
            end
        end
        return res
    end
end

return {
    parse = parseCookie,
    makeSet = makeSetCookie,
    middleware = middleware,
    defualtMiddleware = middleware()
}

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

local match = string.match
local gmatch = string.gmatch
local byte = string.byte
local gsub = string.gsub
local char = string.char
local upper = string.upper
local format = string.format
local floor = math.floor
local concat = table.concat
local tostring = tostring
local tonumber = tonumber
local setmetatable = setmetatable

local uv = require 'luv'

local function bodyParser(req, go)
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

-- Matches characters that have special meanings or can't be printed in a url
local urlSpecials = "[^%w%*%-%.%_]"

-- Pattern to check if a url component is valid. Only checks for valid characters.
local urlValidComponent = "[%w%-%.%_%~%:%/%?%#%[%]%@%!%$%&%'%(%)%*%+%,%;%=%]%*]*"

-- Initialize table for substituting characters in a url string that need to be converted to hex.
local charHexCodes
do
    local hexDigits = '0123456789ABCDEF'
    local function getHexCode(c)
        local b = byte(c)
        local d1 = floor(b / 16)
        return char(37,
            hexDigits:byte(d1 + 1),
            hexDigits:byte(b - 16 * d1 + 1))
    end
    charHexCodes = {}
    for i = 0, 255 do
        local c = char(i)
        if match(c, urlSpecials) then
            local hexCode = getHexCode(c)
            charHexCodes[c] = hexCode
        end
    end
    charHexCodes[" "] = "+"
end

local function urlDecodeFilter(c)
    return char(tonumber(c:sub(2), 16))
end

-- Encodes a Lua string into a url-safe string component by escaping characters.
local function urlEncode(str)
    local ret = gsub(str, urlSpecials, charHexCodes)
    return ret
end

-- Converts a url-string component into a Lua string by unescaping escaped characters in
-- the url. Maps 1 to 1 with util.urlEncode
local function urlDecode(str)
    if not match(str, urlValidComponent) then
        error("Invalid URL Component.")
    end
    local ret = gsub(str, "%+", " ")
    ret = gsub(ret, "%%[0-9a-fA-F][0-9a-fA-F]", urlDecodeFilter)
    return ret
end

-- Encode a Lua object as query string in a URL. The returned query string can be appended
-- to a url by append a '?' character as well as the query string to the original url.
local queryValidKeyTypes = { string = true, number = true }
local queryValidValueTypes = { string = true, number = true, table = true, boolean = true }
local function queryEncode(object)
    local t = {}
    local len = 0
    for k, v in pairs(object) do
        local kstr, vstr
        if not queryValidKeyTypes[type(k)] then
            error("Invalid query key type '" .. type(k) .. "'.")
        else
            kstr = tostring(k)
        end
        local vtype = type(v)
        if not queryValidValueTypes[vtype] then
            error("Invalid query value type '" .. vtype .. "'.")
        elseif vtype == "table" then
            vstr = queryEncode(v)
        else
            vstr = tostring(v)
        end
        t[len + 1] = urlEncode(kstr)
        t[len + 2] = "="
        t[len + 3] = urlEncode(vstr)
        t[len + 4] = "&"
        len = len + 4
    end
    if #t == 0 then
        return ""
    else
        t[#t] = nil
        return concat(t)
    end
end

-- Converts a query string as produced by util.queryEncode to a Lua table.
-- Strings will be converted to numbers if possible.
local function queryDecode(str)
    local ret = nil
    for key, value in gmatch(str, "([^%&%=]+)=([^%&%=]*)") do
        ret = ret or {}
        local keyDecoded = urlDecode(key)
        local valueDecoded = urlDecode(value)
        local valueQueryDecoded = queryDecode(valueDecoded)
        if valueQueryDecoded then valueDecoded = valueQueryDecoded end

        -- Attempt number conversion
        valueDecoded = tonumber(valueDecoded) or valueDecoded
        keyDecoded = tonumber(keyDecoded) or keyDecoded

        ret[keyDecoded] = valueDecoded
    end
    return ret
end

local function queryParser(req, go)
    req.query = queryDecode(req.rawQuery or "")
    return go()
end

local entityToRaw = {
    lt = '<',
    gt = '>',
    amp = '&',
    quot = '"',
    apos = "'",
}

local rawToEntity = {}
for k, v in pairs(entityToRaw) do
    rawToEntity[v] = '&' .. k .. ';'
end

rawToEntity["'"] = "&#39;"
rawToEntity["/"] = "&#47;"

local function htmlEscape(str)
    return (gsub(str, "[}{\">/<'&]", rawToEntity))
end

-- Convert codepoint to string
-- http://stackoverflow.com/questions/26071104/more-elegant-simpler-way-to-convert-code-point-to-utf-8
local function utf8_char(cp)
    if cp < 128 then
        return char(cp)
    end
    local suffix = cp % 64
    local c4 = 128 + suffix
    cp = (cp - suffix) / 64
    if cp < 32 then
      return char(192 + cp, c4)
    end
    suffix = cp % 64
    local c3 = 128 + suffix
    cp = (cp - suffix) / 64
    if cp < 16 then
      return char(224 + cp, c3, c4)
    end
    suffix = cp % 64
    cp = (cp - suffix) / 64
    return char(240 + cp, 128 + suffix, c3, c4)
end

local function htmlUnescapeHelper(n, s)
    if n == '#' then
        return utf8_char(tonumber(s, 10)) -- Decimal
    elseif n == '#x' then
        return utf8_char(tonumber(s, 16)) -- Hex
    elseif n == 'x' then
        return htmlUnescapeHelper('', n .. s)
    elseif entityToRaw[s] then
        return entityToRaw[s]
    else
        -- Default to returning the potential entity as is.
        return ('&%s%s;'):format(n, s)
    end
end

local function htmlUnescape(str)
    return gsub(str, '&(#?x?)(%w+);', htmlUnescapeHelper)
end

local headersMeta = {
    __index = function(self, key)
        if type(key) ~= "string" then
            return rawget(self, key)
        end
        key = lower(key)
        for i = 1, #self do
            local val = rawget(self, i)
            if lower(val[1]) == key then
                return val[2]
            end
        end
    end,
    __newindex = function(self, key, value)
        if type(key) ~= "string" then
            return rawset(self, key, value)
        end
        local wasset = false
        key = lower(key)
        for i = #self, 1, -1 do
            local val = rawget(self, i)
            if lower(val[1]) == key then
                if wasset then
                    local len = #self
                    rawset(self, i, rawget(self, len))
                    rawset(self, len, nil)
                else
                    wasset = true
                    val[2] = value
                end
            end
        end
        if not wasset then
            return rawset(self, #self + 1, {key, value})
        end
    end
}

-- For coercing responses into tables
local toResponse = {
    ['function'] = function(res, req)
        return res(req)
    end,
    ['string'] = function(res)
        return {
            code = 200,
            headers = setmetatable({
                {'Content-Length', #res},
                {'Content-Type', 'text/html'}
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
        return res
    end
}

-- Coerce response into a table
local function responsify(res, req)
    local converter = toResponse[type(res)]
    if converter then
        return converter(res, req)
    else
        error 'expected table as response'
    end
end

local function flexiResponse(req, go)
    return responsify(go())
end

-- Simple logger
local function logger(req, go)
    local time = os.date()
    local res = responsify(go(), req)
    print(format("%s | %s | %s | %s", time, req.method, req.path, res.code))
    return res
end

-- Generate a uuid v4
local uuidv4
do
    local digits = '0123456789abcdef'
    local template = 'xxxxxx-xxxx-4xxx-Nxxx-xxxxxxxxxxxx'
    local random = math.random
    local char = string.char
    math.randomseed(uv.now())
    local function replacer(c)
        if c == 'x' then
            return char(digits:byte(random(1, 16)))
        else
            return char(digits:byte(random(9, 12)))
        end
    end
    function uuidv4()
        local ret = template:gsub('[xN]', replacer)
        return ret
    end
end

return {
    urlEncode = urlEncode,
    urlDecode = urlDecode,
    queryEncode = queryEncode,
    queryDecode = queryDecode,
    htmlEscape = htmlEscape,
    htmlUnescape = htmlUnescape,
    logger = logger,
    bodyParser = bodyParser,
    queryParser = queryParser,
    responsify = responsify,
    flexiResponse = flexiResponse,
    headersMeta = headersMeta,
    uuidv4 = uuidv4
}

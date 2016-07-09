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

--- URL manipulation utilities.
-- @module moonmint.url

local char = string.char
local byte = string.byte
local floor = math.floor
local match = string.match
local tonumber = tonumber
local gsub = string.gsub
local pairs = pairs
local type = type
local tostring = tostring
local concat = table.concat
local gmatch = string.gmatch

-- Matches characters that have special meanings or can't be printed in a url
local urlSpecials = "[^%w%*%-%.%_]"

-- Pattern to check if a url component is valid. Whitelist for valid characters.
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
    return char(tonumber(c, 16))
end

-- Encodes a Lua string into a url-safe string component by escaping characters.
local function urlEncode(str)
    local ret = gsub(str, urlSpecials, charHexCodes)
    return ret
end

local function valid(str)
    return not not match(str, urlValidComponent)
end

-- Converts a url-string component into a Lua string by unescaping escaped characters in
-- the url. Maps 1 to 1 with util.urlEncode
local function urlDecode(str)
    if not valid(str) then
        error "Invalid URL Component."
    end
    local ret = gsub(str, "%+", " ")
    ret = gsub(ret, "%%([0-9a-fA-F][0-9a-fA-F])", urlDecodeFilter)
    return ret
end

-- Encode a Lua object as query string in a URL. The returned query string can be appended
-- to a url by append a '?' character as well as the query string to the original url.
local queryValidKeyTypes = { string = true, number = true, boolean = true }
local queryValidValueTypes = { string = true, number = true, boolean = true }
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

        -- Attempt number conversion
        valueDecoded = tonumber(valueDecoded) or valueDecoded
        keyDecoded = tonumber(keyDecoded) or keyDecoded

        ret[keyDecoded] = valueDecoded
    end
    return ret
end

local defaultOptions = {}
local function urlParse(url, options)
    options = options or defaultOptions
    local protocol, host, port, path, rawQuery =
        match(url, '^(https?)://([^/:]+):?([0-9]*)(/?[^/?]*)/??(.*)$')
    if not protocol then
        error("Not a valid http url: " .. url)
    end
    local tls = protocol == "https"
    if port == '' then
        port = nil
    end
    port = port and tonumber(port) or (tls and 443 or 80)
    if path == "" then
        path = "/"
    end
    local query = nil
    if not options.skipQuery then
        query = queryDecode(rawQuery)
    end
    return {
        tls = tls,
        host = host,
        port = port,
        path = path,
        query = query
    }
end
return {
    encode = urlEncode,
    decode = urlDecode,
    parse = urlParse,
    queryEncode = queryEncode,
    queryDecode = queryDecode,
    valid = valid
}

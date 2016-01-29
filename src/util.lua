local match = string.match
local gmatch = string.gmatch
local byte = string.byte
local gsub = string.gsub
local char = string.char
local upper = string.upper
local floor = math.floor
local concat = table.concat
local tostring = tostring
local tonumber = tonumber

-- Matches characters that have special meanings or can't be printed in a url
local urlSpecials = "[^%w%*%-%.%_]"

-- Pattern to check if a url component is valid. Only checks for valid characters.
local urlValidComponent = "[%w%-%.%_%~%:%/%?%#%[%]%@%!%$%&%'%(%)%*%+%,%;%=%]%*]*"

-- Initialize table for substituting characters in a url string that need to be converted to hex.
local charHexCodes
local reverseCharHexCodes
do
    local hexDigits = { [0] = "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" }
    local function getHexCode(c)
        local b = byte(c)
        local d1 = floor(b / 16)
        return  "%" .. hexDigits[d1] .. hexDigits[b - 16 * d1]
    end
    charHexCodes = {}
    reverseCharHexCodes = {}
    for i = 0, 255 do
        local c = char(i)
        if match(c, urlSpecials) then
            local hexCode = getHexCode(c)
            charHexCodes[c] = hexCode
            reverseCharHexCodes[hexCode] = c
        end
    end
    charHexCodes[" "] = "+"
end

local function urlDecodeFilter(c)
    return reverseCharHexCodes[upper(c)]
end

-- Encodes a Lua string into a url-safe string component by escaping characters.
local function urlEncode(str)
    local ret = gsub(str, urlSpecials, charHexCodes)
    return ret
end

-- Converts a url-string component into a Lua string by unescaping escaped characters in
-- th url. Maps 1 to 1 with util.urlEncode
local function urlDecode(str)
    if not match(str, urlValidComponent) then
        error("Invlaid URL Component.")
    end
    local ret = gsub(str, "%+", " ")
    ret = gsub(ret, "%%[0-9a-fA-F][0-9a-fA-F]", urlDecodeFilter)
    return ret
end

-- Converts a Lua object to JSON. Supprts all key value types except functions,
-- userdata, and threads. Tables cannot be cyclic.
local function jsonEncode(object)

end

-- Converts a string of JSON into a Lua table of value. The table or value will have no
-- function, thread, or userdata keys or values, and will be a directed
-- acyclic graph or single value.
local function jsonDecode(str)

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
    for key, value in gmatch(str, "([^%&]*)=([^%&]*)") do
        ret = ret or {}
        local keyDecoded = urlDecode(key)
        local valueDecoded = urlDecode(value)
        local valueQueryDecoded = queryDecode(value)
        if valueQueryDecoded then valueDecoded = valueQueryDecoded end

        -- Attempt number conversion
        valueDecoded = tonumber(valueDecoded) or valueDecoded
        keyDecoded = tonumber(keyDecoded) or keyDecoded

        ret[keyDecoded] = valueDecoded
    end
    return ret
end

-- Converts a Lua table to a valid cookie string.
local function cookieEncode(object)

end

-- Converts
local function cookieDecode(str)

end

return {
    urlEncode = urlEncode,
    urlDecode = urlDecode,
    jsonEncode = jsonEncode,
    jsonDecode = jsonDecode,
    queryEncode = queryEncode,
    queryDecode = queryDecode,
    cookieEncode = cookieEncode,
    cookieDecode = cookieDecodel
}

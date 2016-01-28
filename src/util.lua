local util = {}

local match = string.match
local byte = string.byte
local gsub = string.gsub
local char = string.char
local upper = string.upper
local floor = math.floor

local urlSpecials = "[^A-Za-z0-9%*%-%.%_% ]"

local hexDigits = {
    [0] = "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"
}

-- Initialize table for substituting characters in a url string that need to be converted to hex.
local charHexCodes
local reverseCharHexCodes
do
    local function getHexCode(c)
        local b = byte(c)
        if b == 32 then return "+" end
        local d1 = floor(b / 16)
        return  "%" .. hexDigits[d1] .. hexDigits[b - 16 * d1]
    end
    charHexCodes = {}
    reverseCharHexCodes = {}
    for i = 0, 255 do
        local c = char(i)
        if match(c, urlSpecials) then
            local hexCode = gerHexCode(c)
            charHexCodes[c] = hexCode
            reverseCharHexCodes[hexCode] = c
        end
    end
end

local function urlDecodeFiter(c)
    return reverseCharHexCodes(upper(c))
end

-- Encodes a Lua string into a url-safe string by escaping characters.
function util.urlEncode(str)
    local ret = gsub(str, urlSpecials, charHexCodes)
    return ret
end

-- Converts a url-string into a Lua string by unescaping escaped characters in
-- th url. Maps 1 to 1 with util.urlEncode
function util.urlDecode(str)
    local ret = gsub(str, "%%[0-9a-fA-F][0-9a-fA-F]", urlDecodeFilter)
    return ret
end

-- Converts a Lua object to JSON. Supprts all key value types except functions,
-- userdata, and threads. Tables cannot be cyclic.
function util.jsonEncode(object)

end

-- Converts a string of JSON into a Lua table of value. The table or value will have no
-- function, thread, or userdata keys or values, and will be a directed
-- acyclic graph or single value.
function util.jsonDecode(str)

end

-- Encode a Lua object as query string in a URL. The returned query string can be appended
-- to a url by append a '?' character as well as the query string to the original url.
function util.queryEncode(object)

end

-- Converts a query string as produced by util.queryEncode to a Lua table.
function util.queryDecode(str)

end

-- Converts a Lua table to a valid cookie string.
function util.cookieEncode(object)

end

-- Converts
function util.cookieDecode(str)

end

return util

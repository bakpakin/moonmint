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

--- HTML utilities.
-- @module moonmint.html

local pairs = pairs
local gsub = string.gsub
local char = string.char
local tonumber = tonumber

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
    local ret = gsub(str, '&(#?x?)(%w+);', htmlUnescapeHelper)
    return ret
end

return {
    encode = htmlEscape,
    decode = htmlUnescape,
    escape = htmlEscape,
    unescape = htmlUnescape
}

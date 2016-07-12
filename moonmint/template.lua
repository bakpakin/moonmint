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

--- String templating that is optimized for HTML.
-- @module moonmint.template

local setmetatable = setmetatable
local rawget = rawget
local byte = string.byte
local tostring = tostring

local bracketTypes = {
    [byte("{")] = "variables",
    [byte("%")] = "lua",
    [byte("$")] = "luaexpr",
    [byte("#")] = "comment",
    [byte('"')] = "literal",
    [byte("'")] = "literal",
}

local btypeClosers = {
    [byte("{")] = byte("}")
}

local function skipToCharWithEscapes(str, i, ch, escape)
    escape = escape or 92
    while(byte(str, i) ~= ch) do
        i = i + 1
        if not byte(str, i) then return 0 end
        if byte(str, i) == escape then
            i = i + 1
        end
    end
    return i
end

local htmlEscapeMap = {
    ['>'] = '&gt;',
    ['<'] = '&lt;',
    ['"'] = '&quot;',
    ["'"] = '&#39;',
    ['/'] = '&#47;',
    ['&'] = '&amp;',
}

local function htmlEscape(str)
    str = str or ''
    return str:gsub("[\">/<'&]", htmlEscapeMap)
end

local backslashEscapeMap = {
    n = '\n',
    t = '\t',
    r = '\r'
}

local function backslashSub(c)
    return backslashEscapeMap[c] or c
end

local function backslashEscape(str)
    return str:gsub('%\\(.)', backslashSub)
end

local function skipToBracket(str, i)
    local j = i
    while true do
        j = skipToCharWithEscapes(str, j, 123)
        if not j or j == 0 then return 0 end
        if bracketTypes[byte(str, j + 1)] or byte(str, j + 1) == 45 then
            return j
        end
        j = j + 1
    end
end

local function getchr(c)
	return "\\" .. c:byte()
end

local function make_safe(text)
	return ("%q"):format(tostring(text)):gsub('\n', 'n'):gsub("[\128-\255]", getchr)
end

local function trim_start(s)
    return s:match("^%s*(.-)$")
end

local function trim_end(s)
    return s:match("^(.-)%s*$")
end

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function primaryEscape(str)
    local buffer = {}
    local index = 1
    local trim_whitespace = false
    while true do

        -- Skip to an open bracket
        local j = skipToBracket(str, index)
        local bnext = str:sub(index, j - 1)
        if trim_whitespace then
            bnext = trim_start(bnext)
        end
        buffer[#buffer + 1] = bnext
        if not j or j == 0 then break end

        -- Get the bracket type
        index = j + 1
        local nextindex = index
        local btype = byte(str, index)
        if btype == 45 then
            nextindex = nextindex + 1
            buffer[#buffer] = trim_end(buffer[#buffer])
            btype = byte(str, nextindex)
        end
        local btypeCloser = btypeClosers[btype] or btype
        local btypename = bracketTypes[btype]

        -- Check for non escape
        if not btypename then
            trim_whitespace = false
        else
            index = nextindex

            -- Skip to the next closing bracket of the same type.
            j = index
            while byte(str, j) ~= 125 do
                trim_whitespace = false
                j = skipToCharWithEscapes(str, j, btypeCloser)
                if j == 0 then return nil, "Unexpected end of template." end
                j = j + 1
                if byte(str, j) == 45 then
                    j = j + 1
                    trim_whitespace = true
                end
            end

            -- Append the body of the brackets
            local htmlEscaped = true
            local body = str:sub(index + 1, j - 2 - (trim_whitespace and 1 or 0))
            if btypename ~= 'literal' then
                body = trim(body)
                if body:byte() == 38 then
                    htmlEscaped = false
                    body = body:sub(2, -1)
                end
            end
            buffer[#buffer + 1] = {
                type = btypename,
                htmlEscape = htmlEscaped,
                body = body
            }

            index = j + 1
        end
    end
    return buffer
end

local function wrapOptions(options)
    return setmetatable({}, {
        __index = function(self, key)
            local raw = rawget(self, key)
            if raw ~= nil then
                return raw
            end
            raw = htmlEscape(options[key])
            self[key] = raw
            return raw
        end
    })
end

return function(body)

    local ast, err = primaryEscape(body)
    if err then
        return error(err)
    end

    local b = {"local a={}\nlocal context, e=...\nlocal c=context\n"}

    for i = 1, #ast do
        local part = ast[i]
        if type(part) == "string" then
            b[#b + 1] = ("a[#a+1]=%s\n"):format(make_safe(backslashEscape(part)))
        elseif part.type == "variables" then
            b[#b + 1] = ("a[#a+1]=%s[%s]\n")
                :format(part.htmlEscape and 'e' or 'c', make_safe(part.body))
        elseif part.type == "lua" then
            b[#b + 1] = ("\n%s\n"):format(part.body)
        elseif part.type == "luaexpr" then
            b[#b + 1] = ("a[#a+1]=(%s)\n"):format(part.body)
        elseif part.type == "literal" then
            local pbody = backslashEscape(part.body)
            if part.htmlEscape then
                pbody = htmlEscape(pbody)
            end
            b[#b + 1] = ("a[#a+1]=%s\n"):format(make_safe(pbody))
        end
    end

    b[#b + 1] = "return table.concat(a)"
    local code = table.concat(b)
    local ret
    ret, err = (loadstring or load)(code)
    if ret then
        return function(options)
            return ret(options, wrapOptions(options))
        end
    else
        error(err)
    end

end

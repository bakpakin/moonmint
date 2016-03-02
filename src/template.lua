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

--[[lit-meta
name = "bakpakin/moonmint-template"
version = "0.0.1-2"
dependencies = {}
description = "Templating library and middleware for the moonmint framework."
tags = {"moonmint", "template", "templating"}
license = "MIT"
author = { name = "Calvin Rose" }
homepage = "https://github.com/bakpakin/moonmint"
]]

local byte = string.byte

local bracketTypes = {
    [byte("{")] = "variables",
    [byte("%")] = "lua",
    [byte("#")] = "comment"
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
	return ("%q"):format(text):gsub('\n', 'n'):gsub("[\128-\255]", getchr)
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
        local btype = byte(str, index)
        if btype == 45 then
            index = index + 1
            buffer[#buffer] = trim_end(buffer[#buffer])
            btype = byte(str, index)
        end
        local btypeCloser = btypeClosers[btype] or btype
        local btypename = bracketTypes[btype]

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
        buffer[#buffer + 1] = {
            type = btypename,
            body = trim(str:sub(index + 1, j - 2 - (trim_whitespace and 1 or 0)))
        }

        index = j + 1
    end
    return buffer
end

return function(body)

    local ast, err = primaryEscape(body)
    if err then
        return nil, err
    end

    local b = {"local __a__={}\nlocal context=...\nlocal _c=context\n"}

    for i = 1, #ast do
        local part = ast[i]
        if type(part) == "string" then
            b[#b + 1] = ("__a__[#__a__+1]=%s\n"):format(make_safe(part))
        elseif part.type == "variables" then
            b[#b + 1] = ("__a__[#__a__+1]=%s or _c.%s\n"):format(part.body, part.body)
        elseif part.type == "lua" then
            b[#b + 1] = ("\n%s\n"):format(part.body)
        end
    end

    b[#b + 1] = "return table.concat(__a__)"
    local code = table.concat(b)
    local ret
    ret, err = loadstring(code)
    return ret, err

end

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

local setmetatable = setmetatable
local headers_mt = require './httpheader'

local response_mt

local response = setmetatable({}, {
    __call = function(self, t)
        t = t or { headers = {} }
        setmetatable(t.headers, headers_mt)
        return setmetatable(t, response_mt)
    end
})

response_mt = { __index = response }

function response:set(name, value)
    self.headers[name] = value;
    return self
end

function response:get(name)
    return self.headers[name]
end

local noop = function() end

function response:send(body)
    self.code = 200
    self.body = body or self.body or ""
    self.headers["Content-Type"] = self.mime or 'text/html'
    return self
end

function response:append(field, ...)
    local value
    if type(...) == 'table' then
        value = table.concat(...)
    else
        value = table.concat({...})
    end
    local prev = self.headers[field]
    if prev then
        self.headers[field] = prev .. tostring(value)
    else
        self.headers[field] = tostring(value)
    end
end

function response:redirect(location)
    self.code = 302
    self.headers["Location"] = location
    return self
end

return response

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
local rawget = rawget
local rawset = rawset
local match = string.match

local headers_mt = require './httpheader'
local util = require './util'
local JSON = require 'json'
local queryDecode = util.queryDecode

local request_mt

local request = setmetatable({}, {
    __call = function(self, t)
        t = t or { headers = {} }
        setmetatable(t.headers, headers_mt)
        return setmetatable(t, request_mt)
    end
})

local lazy_loaders = {
    query = function(self)
        local path, rawquery = match(self.url, "^(.+)[%?%#](.*)$")
        if path then
            rawset(self, "rawquery", rawquery)
            rawset(self, "query", queryDecode(rawQuery))
        else
            rawset(self, "query", {})
        end
    end,
    json = function(self)
        rawset(self, "json", json.decode(self.body))
    end
}

request_mt = {
    __index = function(self, key)
        local value = rawget(self, key)
        if value == nil then
            value = request[key]
            if value == nil then
                local loader = lazy_loaders[key]
                if loader then
                    loader(self)
                    value = rawget(self, key)
                end
            end
        end
        return value
    end
}

function request:set(name, value)
    self.headers[name] = value;
    return self
end

function request:get(name)
    return self.headers[name]
end

return request

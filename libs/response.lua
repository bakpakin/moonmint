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

exports.name = 'bakpakin/moonmint-response'
exports.version = '0.0.1-1'
exports.dependencies = {}
exports.description = "HTTP Response object in the moonmint framework."
exports.tags = {"moonmint", "response"}
exports.license = "MIT"
exports.author = { name = "Calvin Rose" }
exports.homepage = "https://github.com/bakpakin/moonmint"

local response = {}
local response_mt = { __index = response }

local headers_mt = {
    __index = function(self, key)
        if type(key) ~= "string" then
            return rawget(self, key)
        end
        key = lower(key)
        for i = 1, #self, 2 do
            if self[i] == key then
                return self[i + 1]
            end
        end
    end,
    __newindex = function(self, key, value)
        if type(key) ~= "string" then
            return rawset(self, key, value)
        end
        key = lower(key)
        for i = #self - 1, 1, -2 do
            if lower(self[i]) == key then
                local len = #self
                self[i] = self[len - 1]
                self[i + 1] = self[len]
                self[len] = nil
                self[len - 1] = nil
            end
        end
        if value == nil then return end
        rawset(self, key, value)
    end
}

function response:set(name, value)
    self.headers[name] = value;
    return self
end

function response:get(name)
    return self.headers[name]
end

function response:send(body)
    self.code = 200
    self.body = body
end

return response_mt

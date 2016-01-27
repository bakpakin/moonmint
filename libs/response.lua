--[[lit-meta
name = "bakpakin/moonmint-response"
version = "0.0.1-1"
dependencies = {}
description = "HTTP Response object in the moonmint framework."
tags = {"moonmint", "response"}
author = { name = "Calvin Rose" }
license = "MIT"
homepage = "https://github.com/bakpakin/moonmint"
]]

local setmetatable = setmetatable
local type = type
local rawset = rawset
local rawget = rawget

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

function response.new(t)
    t = t or { headers = {} }
    setmetatable(t.headers, headers_mt)
    return setmetatable(t, response_mt)
end

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

return response

local setmetatable = setmetatable
local headers_mt = require './httpheader'

local request = {}
local request_mt = { __index = request }

function request.new(t)
    t = t or { headers = {} }
    setmetatable(t.headers, headers_mt)
    return setmetatable(t, request_mt)
end

function request:set(name, value)
    self.headers[name] = value;
    return self
end

function request:get(name)
    return self.headers[name]
end

return request

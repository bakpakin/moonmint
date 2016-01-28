local setmetatable = setmetatable
local headers_mt = require './httpheader'

local response = {}
local response_mt = { __index = response }

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
    self.body = body or self.body or ""
    self.done = true
    return self
end

function response:redirect(location)
    self.code = 302
    self.headers["Location"] = location
    self.done = true
    return self
end

return response

local lower = string.lower
local type = type
local rawset = rawset
local rawget = rawget

return {
    __index = function(self, key)
        if type(key) ~= "string" then
            return rawget(self, key)
        end
        key = lower(key)
        for i = 1, #self do
            local val = rawget(self, i)
            if lower(val[1]) == key then
                return val[2]
            end
        end
    end,
    __newindex = function(self, key, value)
        if type(key) ~= "string" then
            return rawset(self, key, value)
        end
        local wasset = false
        key = lower(key)
        for i = #self, 1, -1 do
            local val = rawget(self, i)
            if lower(val[1]) == key then
                if wasset then
                    local len = #self
                    rawset(self, i, rawget(self, len))
                    rawset(self, len, nil)
                else
                    wasset = true
                    val[2] = value
                end
            end
        end
        if not wasset then
            return rawset(self, #self + 1, {key, value})
        end
    end
}


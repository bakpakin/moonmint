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


--[[
Copyright (c) 2016 Calvin Rose
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

local util = require 'moonmint.util'

local function deepEquals(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) == 'table' then
        for k, v in pairs(a) do
            if not deepEquals(v, b[k]) then
                return false
            end
        end
        -- Check if b has extra kv pairs
        for k in pairs(b) do
            if a[k] == nil then
                return false
            end
        end
        return true
    end
    return a == b
end

local function testEncodeGen(encode, decode)
    return function(data, encoded_form)
        local encoded_data = encode(data)
        if encoded_form then
            assert(deepEquals(encoded_data, encoded_form))
        end
        assert(deepEquals(data, decode(encoded_data)))
    end
end

local function agentTester(cb)
    local moonmint = require 'moonmint'
    local agent = require 'moonmint.agent'
    local testServer = moonmint():startLater {
        errHand = false
    }
    local testAgent = agent:url('http://localhost:8080'):module()
    local ok, err
    moonmint.go(function()
        ok, err = pcall(cb, testAgent, testServer)
        agent:close()
        testServer:close()
    end)
    if not ok then
        error(err)
    end
end

return {
    agentTester = agentTester,
    encode = testEncodeGen,
    deepEquals = deepEquals
}

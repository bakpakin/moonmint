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

local function testEncodeGen(encode, decode, assert)
    return function(data, encoded_form)
        local encoded_data = encode(data)
        if encoded_form then
            assert.are.equal(encoded_data, encoded_form)
        end
        assert.are.same(data, decode(encoded_data))
    end
end

local function makeTestServer(app, start)
    local moonmint = require('moonmint')
    local done = false
    local port = 8000
    while not done do
        local testserver = moonmint()
        testserver:bind {
            port = port,
            onStart = function()
                return start(port)
            end
        }
        done = pcall(function()
            testserver:start()
        end)
        port = port + 1
    end
end

local function agentTester(app, start)
    local agent = require 'moonmint.agent'
    makeTestServer(app, function(port)
        start(agent:url('http://localhost:' .. port):module())
    end)
end

return {
    makeTestServer = makeTestServer,
    agentTester = agentTester,
    encode = testEncodeGen
}

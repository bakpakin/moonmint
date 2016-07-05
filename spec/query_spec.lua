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

local url = require 'moonmint.url'
local helper = require 'spec.helper'
local testQuery = helper.encode(url.queryEncode, url.queryDecode, assert)

describe("Query encoding/decoding", function()

    it("Encodes and decodes strings", function()
        testQuery({
            hello = "kitty",
            cat = "yum"
        })
    end)

    it("Encodes and decodes numbers and strings", function()
        testQuery({
            [0] = "go",
            jump = "How high?++++",
            anumber = 145.2
        })
    end)

    it("Encodes and decodes table keys", function()
        testQuery({
            [1] = 2,
            nestedtable = {
                [1] = 3,
                anothernestedtable = {
                    1, 2, 3, 4, 5, 6
                }
            }
        })
    end)

end)

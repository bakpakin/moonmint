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
local testURL = helper.encode(url.encode, url.decode)

test("Url encoding/decoding", function()

    test("Does basic encoding/decoding of simple strings", function()
        testURL("abcdefg")
        testURL("1233456")
    end)

    test("Encodes/decodes url special characters", function()
        testURL("!@#$%^&*()_+.,?:;\\")
    end)

    test("Encodes/decodes those darned plus signs", function()
        testURL("+ + +", "%2B+%2B+%2B")
    end)

    test("Encodes/decodes all possible bytes", function()
        for i = 0, 255 do
            testURL(string.char(i))
        end
    end)

    test("Encodes/decodes strings of all possible bytes", function()
        for i = 0, 250 do
            testURL(string.char(i, i + 1, i + 2, i + 3, i + 4, i + 5))
        end
    end)

end)

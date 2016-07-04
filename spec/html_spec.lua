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

local html = require 'moonmint.html'
local helper = require 'spec.helper'
local testHTML = helper.encode(html.encode, html.decode, assert)

describe("HTML encoding/decoding", function()

    it("Encodes/decodes simple html strings.", function()
        testHTML("zyxwvut")
        testHTML("1233456")
    end)

    it("Encodes/decodes strings with tags.", function()
        testHTML("zyxwvut<hi>akjsk</hi>")
        testHTML("1233456</div><div class=\"giggles\">")
    end)

    it("Encodes/decodes all bytes.", function()
        for i = 0, 255 do
            testHTML(string.char(i))
        end
    end)

    it("Encodes/decodes strings of all bytes.", function()
        for i = 0, 250 do
            testHTML(string.char(i, i + 1, i + 2, i + 3, i + 4, i + 5))
        end
    end)

end)

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

local format = string.format
local concat = table.concat
local response = require 'moonmint.response'

local function bodyParser(req, go)
    local parts = {}
    local read = req.read
    for chunk in read do
        if #chunk > 0 then
            parts[#parts + 1] = chunk
        else
            break
        end
    end
    req.body = #parts > 0 and concat(parts) or nil
    return go()
end

-- Simple logger
local function logger(req, go)
    local time = os.date()
    local res = go()
    print(format("%s | %s | %s | %s",
        time,
        req.method,
        req.path,
        res and (res.code or 200) or 'No Response'))
    return res
end

local function teapot()
    return response(418)
end

return {
    logger = logger,
    bodyParser = bodyParser,
    queryParser = queryParser,
    teapot = teapot
}

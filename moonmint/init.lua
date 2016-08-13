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

local moonmint_mt = {}
local moonmint = setmetatable({}, moonmint_mt)

local server = require "moonmint.server"
moonmint.server = server
moonmint.static = require "moonmint.static"
moonmint.template = require "moonmint.template"
moonmint.router = require "moonmint.router"
moonmint.fs = require "moonmint.fs"
moonmint.util = require "moonmint.util"
moonmint.url = require "moonmint.url"
moonmint.html = require "moonmint.html"
moonmint.response = require "moonmint.response"
moonmint.agent = require "moonmint.agent"

function moonmint.go(fn, ...)
    if fn then
        coroutine.wrap(fn)(...)
    end
    return require('luv').run()
end

function moonmint_mt.__call(_, ...)
    return server(...)
end

return moonmint

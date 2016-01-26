--[[
Copyright (c) 2015 Calvin Rose
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

local byte = string.byte
local match = string.match
local gmatch = string.gmatch
local gsub = string.gsub
local sub = string.sub
local find = string.find
local format = string.format
local concat = table.concat
local setmetatable = setmetatable

local router = setmetatable({}, {
    __call = function(self, ...)
        return self.new(...)
    end
})

local router_mt

--- Create a new Router.
function router.new()
    return setmetatable({}, router_mt)
end

-- Helper function to compile a function that matches certain hosts. Used
-- internally by router:route
local function compileHost(hostPattern)
    -- Escape everything except globs
    local pat = gsub(hostPattern, "[%%%^%$%(%)%.%[%]%+%-%?]", "%%%1")
    pat = gsub(pat, "%*%*", ".+")
    pat = gsub(pat, "%*", "[^%.]+")
    return function(str)
        return #match(str, pat) > 0
    end
end

-- Turn a url routing pattern into a Lua pattern. Also returns an array of the
-- names of the capture groups.
local function makeRoutePattern(urlPattern)
    local pathCaptures = {}
    local tab = {}
    for part in gmatch(urlPattern, "[^/]+") do
        if byte(part) == byte(":") then
            if byte(part, #part) == byte(":") then
                assert(match(part, "^:[_%w]+:$"), ("Invalid capture: %s"):format(part))
                pathCaptures[#pathCaptures + 1] = sub(part, 2, -2)
                tab[#tab + 1] = "(.+)"
            else
                assert(match(part, "^:[_%w]+$"), ("Invalid capture: %s"):format(part))
                pathCaptures[#pathCaptures + 1] = sub(part, 2, -1)
                tab[#tab + 1] = "([^/]+)"
            end
        else
            tab[#tab + 1] = gsub(part, "[%%%^%$%(%)%.%[%]%*%+%-%?]", "%%%1")
        end
    end
    local pattern = "^/?" .. concat(tab, "/") .. "/?$"
    return pattern, pathCaptures
end

-- Helper function to compile a route matching function that also returns
-- captures. Used internally by router:route
local function compileRoute(urlPattern)
    local pattern, pathCaptures = makeRoutePattern(urlPattern)
    if #pathCaptures == 0 then
        return function(str)
            return (str and match(str, pattern)) and {}
        end
    else
        return function(str)
            if not str then return false end
            local matches = { match(str, pattern) }
            if #matches ~= 0 then
                for i = 1, #pathCaptures do
                    matches[pathCaptures[i]] = matches[i]
                end
                return matches
            end
        end
    end
end

-- Helper function to add parameters to a request without deleting previous
-- parameters
local function addParams(req, params)
    local p = req.params
    if p then
        for k, v in pairs(params) do
            p[k] = v
        end
    else
        req.params = params
    end
end

-- Helper function to wrap middleware under a sub-route.
local function subroute(self, path, middleware)
    local pat, captures = makeRoutePattern(path)
    pat = sub(pat, 1, -4) .. "/(.+)/?$"
    return self:use(function(req, res, go)
        local pathKey = req.url and "url" or "path"
        local oldPath = req[pathKey]
        local matches = { match(oldPath, pat) }
        if #matches == 0 then
            return go()
        end
        local newPath = matches[#matches]
        local resetPath = not req.fullpath
        if resetPath then
            req.fullpath = oldPath
        end
        req[pathKey] = newPath
        req.params = req.params or {}
        local reqp = req.params
        for i = 1, #captures do
            reqp[#reqp + 1] = matches[i]
            reqp[captures[i]] = matches[i]
        end
        local goCalled = false
        local function mwGo()
            goCalled = true
        end
        middleware(req, res, mwGo)

        -- Reset the request path no matter what, even if the event is consumed.
        req[pathKey] = oldPath
        if resetPath then
            req.fullpath = nil
        end
        if goCalled then
            return go()
        end
    end)
end

--- Make this router use middleware. Returns the middleware.
function router:use(middleware, b)
    if b then
        -- middleware is actually a path, and b is the middleware
        return subroute(self, middleware, b)
    end
    self[#self + 1] = middleware
    return self
end

--- Creates a new route for the router.
function router:route(options, callback)

    -- Type checking
    assert(callback, "Expected a callback function as the second argument.")
    if type(options) == "string" then
        options = {path = options}
    end
    assert(type(options) == "table", "Expected the first argument options to be a table or string.")

    local routeMethod = (options.method or "*"):upper()
    local checkMethod = routeMethod ~= "*"
    local routeF = options.path and compileRoute(options.path)
    local hostF = options.host and compileHost(options.host)
    return self:use(function(req, res, go)
        if checkMethod then
            if req.method ~= routeMethod then return go() end
        end
        if hostF and not hostF(req.host) then return go() end
        local matches = routeF and routeF(req.url or req.path)
        if routeF and not matches then return go() end
        addParams(req, matches)
        return callback(req, res, go)
    end)
end

--- Routes the request and response through the appropriate middlewares.
function router:doRoute(req, res, go)
    local run
    local i = 1
    local function runNext()
        i = i + 1
        return run()
    end
    function run()
        local mw = self[i]
        if mw then
            return mw(req, res, runNext)
        elseif go then
            return go()
        end
    end
    return run()
end

-- Helper to make aliases for different common routes.
local function makeAlias(method, alias)
    router[alias] = function(self, path, callback)
        return self:route({
            method = method,
            path = path
        }, callback)
    end
end

makeAlias("GET", "get")
makeAlias("PUT", "put")
makeAlias("POST", "post")
makeAlias("DELETE", "delete")
makeAlias("HEAD", "head")
makeAlias("OPTIONS", "options")
makeAlias("*", "all")

router_mt = {
    __index = router,
    __call = router.doRoute
}

router.metatable = router_mt

return router

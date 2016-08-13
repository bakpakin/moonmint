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

--- Routing and sub apps.
-- @module moonmint.router

local response = require 'moonmint.response'

local byte = string.byte
local match = string.match
local gmatch = string.gmatch
local gsub = string.gsub
local sub = string.sub
local concat = table.concat
local setmetatable = setmetatable

local router_mt

-- Calling router creates a new router
local router = setmetatable({}, {
    __call = function(_, options)
        options = options or {
            mergeParams = true
        }
        return setmetatable({
            mergeParams = not not options.mergeParams,
            mergeName = options.mergeName
        }, router_mt)
    end
})

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
    local pattern
    if #tab == 0 then
        pattern = "^/?$"
    else
        pattern = "^/" .. concat(tab, "/") .. "/?$"
    end
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

-- If a middleware calls go multiple times, restart the chain at that point.
local function chain(middlewares, i, req, go)
    local mw = middlewares[i]
    if mw then
        return mw(req, function()
            return chain(middlewares, i + 1, req, go)
        end)
    elseif go then
        return go()
    end
end

-- Converts values besides functions to middleware
local function toMiddleware(mw)
    if type(mw) == 'function' then
        return mw
    elseif type(mw) == 'table' and
        getmetatable(mw) and
        getmetatable(mw).__call then
        return mw
    else
        local res = response(mw)
        return function()
            return res
        end
    end
end

-- Collapse multiple middlewares into one.
local function makeChain(...)
    if select('#', ...) < 2 then
        return toMiddleware(...)
    else
        local middlewares = {...}
        -- Convert string middlewares to functions
        for i = 1, #middlewares do
            middlewares[i] = toMiddleware(middlewares[i])
        end
        return function(req, go)
            return chain(middlewares, 1, req, go)
        end
    end
end

-- Helper function to wrap middleware under a sub-route.
local function subroute(self, path, ...)
    local pat, captures = makeRoutePattern(path)
    pat = sub(pat, 1, -4) .. "(/?.*)/?$"

    local middleware = makeChain(...)

    return self:use(function(req, go)
        local oldPath = req.path
        local matches = { match(oldPath, pat) }
        if #matches == 0 then
            return go()
        end
        local newPath = matches[#matches]
        if newPath == "" then newPath = "/" end
        if byte(newPath, -1) == byte("/") then
            newPath = newPath:sub(1, -2)
        end
        if byte(newPath) ~= byte("/") then
            newPath = "/" .. newPath
        end
        req.path = newPath
        if self.mergeParams then
            req.params = req.params or {}
            local reqp
            if self.mergeName then
                reqp = req.params[self.mergeName] or {}
                self.params[self.mergeName] = reqp
            else
                reqp = self.params
            end
            for i = 1, #captures do
                reqp[#reqp + 1] = matches[i]
                reqp[captures[i]] = matches[i]
            end
        end
        local res = middleware(req, function()
            req.path = oldPath
            return go()
        end)
        req.path = oldPath
        return res
    end)
end

-- Make this router use middleware. Returns the router.
function router:use(...)
    if type(...) == "string" then
        return subroute(self, ...)
    end
    for i = 1, select("#", ...) do
        local mw = toMiddleware(select(i, ...))
        self[#self + 1] = mw
    end
    return self
end

-- Creates a new route for the router.
function router:route(options, ...)

    -- Type checking
    assert(..., "Expected a callback function as the second argument.")
    if type(options) == "string" then
        options = {path = options}
    end
    assert(type(options) == "table", "Expected the first argument options to be a table or string.")

    local checkMethod = options.method and (options.method ~= "*")
    local routeF = nil
    local hostF = nil
    local methodF = nil

    if options.path then
        if type(options.path) == 'function' then
            routeF = options.path
        else
            routeF = compileRoute(options.path)
        end
    end

    if options.host then
        if type(options.host) == 'function' then
            hostF = options.host
        else
            hostF = compileHost(options.host)
        end
    end

    if options.method then
        if type(options.method) == 'function' then
            methodF = options.method
        elseif type(options.method) == 'table' then
            local okMethods = {}
            for _, m in ipairs(options.methods) do
                okMethods[m:upper()] = true
            end
            function methodF(method)
                return okMethods[method]
            end
        else
            local m = options.method
            function methodF(method)
                return method == m
            end
        end
    end

    local callback = makeChain(...)
    return self:use(function(req, go)
        if checkMethod and not methodF(req.method) then return go() end
        if hostF and not hostF(req.host) then return go() end
        if routeF then
            local matches = routeF(req.path)
            if not matches then return go() end
            addParams(req, matches)
        end
        return callback(req, go)
    end)
end

-- Routes the request through the appropriate middlewares.
function router:doRoute(req, go)
    return chain(self, 1, req, go)
end

-- Helper to make aliases for different common routes.
local function makeAlias(method, alias)
    router[alias] = function(self, path, ...)
        return self:route({
            method = method,
            path = path
        }, ...)
    end
end

local function alias(method)
    makeAlias(method:upper(), method:lower())
end

makeAlias("*", "all")

-- HTTP version 1.1
alias('get')
alias('put')
alias('post')
alias('delete')
alias('head')
alias('options')
alias('trace')
alias('connect')

-- WebDAV
alias('bcopy')
alias('bdelete')
alias('bmove')
alias('bpropfind')
alias('bproppatch')
alias('copy')
alias('lock')
alias('mkcol')
alias('move')
alias('notify')
alias('poll')
alias('propfind')
alias('search')
alias('subscribe')
alias('unlock')
alias('unsubscribe')

router_mt = {
    __index = router,
    __call = router.doRoute
}

router.metatable = router_mt

return router

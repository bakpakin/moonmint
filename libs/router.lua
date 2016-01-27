--[[lit-meta
name = "bakpakin/moonmint-router"
version = "0.0.1-2"
dependencies = {}
description = "Generic router middleware for the moonmint framework."
tags = {"moonmint", "router", "framework", "routing"}
license = "MIT"
author = { name = "Calvin Rose" }
homepage = "https://github.com/bakpakin/moonmint"
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

local router_mt

-- Calling router creates a new router
local router = setmetatable({}, {
    __call = function(self)
        return setmetatable({}, router_mt)
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
local function subroute(self, path, ...)
    local pat, captures = makeRoutePattern(path)
    pat = sub(pat, 1, -4) .. "/(.+)/?$"

    local middleware
    if select("#", ...) > 1 then
        middleware = router():use(...)
    else
        middleware = ...
    end

    return self:use(function(req, res)
        local oldPath = req.path
        local matches = { match(oldPath, pat) }
        if #matches == 0 then
            return
        end
        local newPath = matches[#matches]
        req.path = newPath
        req.params = req.params or {}
        local reqp = req.params
        for i = 1, #captures do
            reqp[#reqp + 1] = matches[i]
            reqp[captures[i]] = matches[i]
        end
        middleware(req, res)

        -- Reset the request path no matter what, even if the event is consumed.
        req.path = oldPath
    end)
end

--- Make this router use middleware. Returns the middleware.
function router:use(...)
    if type(...) == "string" then
        return subroute(self, ...)
    end
    for i = 1, select("#", ...) do
        self[#self + 1] = select(i, ...)
    end
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
    return self:use(function(req, res)
        if checkMethod then
            if req.method ~= routeMethod then return end
        end
        if hostF and not hostF(req.host) then return end
        local matches = routeF and routeF(req.path)
        if routeF and not matches then return end
        addParams(req, matches)
        return callback(req, res)
    end)
end

--- Routes the request and response through the appropriate middlewares.
function router:doRoute(req, res)
    for i = 1, #self do
        if res.done then break end
        self[i](req, res)
    end
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

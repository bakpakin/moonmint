local format = [[
package = "moonmint"
version = "%s"
source = {
    url = "file:////0.0.0.0%s/%s"
}
description = {
    homepage = "https://github.com/bakpakin/moonmint",
    summary = "Express like web framework for Lua",
    license = "MIT",
}
dependencies = {
    "lua >= 5.1",
    "luv ~> 1.8",
    "luv-coro-channel >= 1.8",
    "luv-coro-net >= 1.8",
    "mimetypes >= 1.0",
    "bkopenssl >= 0.0",
    "bit32"
}
build = {
    type = "builtin",
    modules = {
        ["moonmint"] = "moonmint/init.lua",

        ["moonmint.server"] = "moonmint/server.lua",
        ["moonmint.static"] = "moonmint/static.lua",
        ["moonmint.util"] = "moonmint/util.lua",
        ["moonmint.router"] = "moonmint/router.lua",
        ["moonmint.template"] = "moonmint/template.lua",
        ["moonmint.fs"] = "moonmint/fs.lua",

        ["moonmint.deps.codec.http"] = "moonmint/deps/codec/http.lua",
        ["moonmint.deps.codec.tls"] = "moonmint/deps/codec/tls.lua",
        ["moonmint.deps.pathjoin"] = "moonmint/deps/pathjoin.lua"
    }
}
]]

local currentDirectory = io.popen('pwd'):read'*l'
local version = 'local-0'
local target = ('moonmint-%s.rockspec'):format(version)

local f = assert(io.open(target, 'w'))
f:write(format:format(version, currentDirectory, target))
f:close();
print(('Wrote to %s.'):format(target))

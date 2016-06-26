package = "moonmint"
version = "0.0.0-9"
source = {
    url = "git://github.com/bakpakin/moonmint.git",
    tag = version
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
        ["moonmint"] = "init.lua",

        ["moonmint.server"] = "src/server.lua",
        ["moonmint.static"] = "src/static.lua",
        ["moonmint.util"] = "src/util.lua",
        ["moonmint.router"] = "src/router.lua",
        ["moonmint.template"] = "src/template.lua",
        ["moonmint.fs"] = "src/fs.lua",

        ["moonmint.deps.codec.http"] = "deps/codec/http.lua",
        ["moonmint.deps.codec.tls"] = "deps/codec/tls.lua",
        ["moonmint.deps.pathjoin"] = "deps/pathjoin.lua",
        ["moonmint.deps.headers"] = "deps/headers.lua",
        ["moonmint.deps.request"] = "deps/request.lua",
        ["moonmint.deps.response"] = "deps/response.lua"
    }
}

package = "moonmint"
version = "0.0.0-7"
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
    "luv-coro-fs >= 1.8",
    "mimetypes >= 1.0",
    "lua-path",
    "bkopenssl >= 0.0",
    "bit32"
}
build = {
    type = "builtin",
    modules = {
        ["moonmint"] = "init.lua",
        ["moonmint.codec.http"] = "src/codec/http.lua",
        ["moonmint.codec.tls"] = "src/codec/tls.lua",
        ["moonmint.codec.tls.rootca"] = "src/codec/root_ca.dat.lua",
        ["moonmint.server"] = "src/server.lua",
        ["moonmint.static"] = "src/static.lua",
        ["moonmint.util"] = "src/util.lua",
        ["moonmint.router"] = "src/router.lua",
        ["moonmint.template"] = "src/template.lua",
    }
}

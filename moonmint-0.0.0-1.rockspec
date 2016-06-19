package = "moonmint"
version = "0.0.0-1"
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
    "luv ~> 1.9",
    "mimetypes >= 1.0",
    "lua-path >= 2.0",
    "openssl"
}
build = {
    type = "builtin",
    modules = {
        ["moonmint"] = "init.lua",
        ["moonmint.server"] = "src/server.lua",
        ["moonmint.static"] = "src/static.lua",
        ["moonmint.util"] = "src/util.lua",
        ["moonmint.router"] = "src/router.lua",
        ["moonmint.template"] = "src/template.lua"
    }
}

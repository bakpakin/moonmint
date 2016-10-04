package = "moonmint"
version = "scm-5"
source = {
    url = "git://github.com/bakpakin/moonmint.git",
    tag = "master"
}
description = {
    homepage = "https://github.com/bakpakin/moonmint",
    summary = "Web framework for Lua",
    license = "MIT",
}
dependencies = {
    "lua >= 5.1",
    "luv ~> 1.8",
    "mimetypes >= 1.0",
    "bit32"
}
build = {
    type = "builtin",
    modules = {
        ["moonmint"] = "moonmint/init.lua",

        ["moonmint.agent"] = "moonmint/agent.lua",
        ["moonmint.cookie"] = "moonmint/cookie.lua",
        ["moonmint.fs"] = "moonmint/fs.lua",
        ["moonmint.html"] = "moonmint/html.lua",
        ["moonmint.response"] = "moonmint/response.lua",
        ["moonmint.router"] = "moonmint/router.lua",
        ["moonmint.server"] = "moonmint/server.lua",
        ["moonmint.static"] = "moonmint/static.lua",
        ["moonmint.template"] = "moonmint/template.lua",
        ["moonmint.url"] = "moonmint/url.lua",
        ["moonmint.util"] = "moonmint/util.lua",

        ["moonmint.deps.http-headers"] = "moonmint/deps/http-headers.lua",
        ["moonmint.deps.coro-wrapper"] = "moonmint/deps/coro-wrapper.lua",
        ["moonmint.deps.httpCodec"] = "moonmint/deps/httpCodec.lua",
        ["moonmint.deps.stream-wrap"] = "moonmint/deps/stream-wrap.lua",
        ["moonmint.deps.secure-socket.biowrap"] = "moonmint/deps/secure-socket/biowrap.lua",
        ["moonmint.deps.secure-socket.context"] = "moonmint/deps/secure-socket/context.lua",
        ["moonmint.deps.secure-socket.root_ca"] = "moonmint/deps/secure-socket/root_ca.lua",
        ["moonmint.deps.secure-socket"] = "moonmint/deps/secure-socket/init.lua",
        ["moonmint.deps.pathjoin"] = "moonmint/deps/pathjoin.lua"
    }
}

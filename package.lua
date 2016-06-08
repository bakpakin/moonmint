return {
    name = "bakpakin/moonmint",
    version = "1.0.3-2",
    description = "Web Framework for lit.",
    tags = { "lua", "lit", "luvit", "moonmint", "router", "server", "framework"},
    license = "MIT",
    author = { name = "Calvin Rose", email = "calsrose@gmail.com" },
    homepage = "https://github.com/bakpakin/moonmint",
    dependencies = {
        "creationix/mime@0.1.2",
        "creationix/hybrid-fs@0.1.1",
        "creationix/coro-wrapper@1.0.0",
        "creationix/coro-net@1.1.1",
        "creationix/coro-tls@1.3.1",
        "luvit/http-codec@1.0.0",
        "luvit/json@2.5.1"
    },
    files = {
        "package.lua",
        "init.lua",
        "src/**.lua"
    }
}

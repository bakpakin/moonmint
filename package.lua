return {
    name = "bakpakin/moonmint",
    version = "0.0.1-6",
    description = "Web Framework for lit.",
    tags = { "lua", "lit", "luvit", "moonmint", "router", "server", "framework"},
    license = "MIT",
    author = { name = "Calvin Rose", email = "calsrose@gmail.com" },
    homepage = "https://github.com/bakpakin/moonmint",
    dependencies = {
        -- External Deps
        "creationix/coro-wrapper@1.0.0",
        "creationix/coro-net@1.1.1",
        "creationix/coro-tls@1.3.1",
        "luvit/http-codec@1.0.0",
        "luvit/querystring@1.0.2",
        -- Internal Deps
        "bakpakin/moonmint-server@0.0.1",
        "bakpakin/moonmint-router@0.0.1",
        "bakpakin/moonmint-static@0.0.1",
        "bakpakin/moonmint-template@0.0.1"
    },
    files = {
        "package.lua",
        "init.lua",
        "src/**.lua"
    }
}

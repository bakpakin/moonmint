return {
    name = "bakpakin/moonmint",
    version = "0.0.1-2",
    description = "Web Framework for lit.",
    tags = { "lua", "lit", "luvit", "moonmint", "router", "server", "framework"},
    license = "MIT",
    author = { name = "Calvin Rose", email = "calsrose@gmail.com" },
    homepage = "https://github.com/bakpakin/moonmint",
    dependencies = {
        "bakpakin/moonmint-server@0.0.1",
        "bakpakin/moonmint-router@0.0.1",
        "bakpakin/moonmint-static@0.0.1",
        "bakpakin/moonmint-template@0.0.1"
    },
    files = {
        "package.lua",
        "init.lua"
    }
}

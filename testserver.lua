-- In a real app, this should be "require 'moonmint-server'"
local server = require "server"
local app = server()

app:bind{}

app:get("/", function(req, res, go)
    res:send("Hello, World!")
end)

app:start()

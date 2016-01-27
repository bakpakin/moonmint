local app = require("moonmint")()

app:get("/", function(req, res)
    res:send("Hello, World!")
end)

app:start()

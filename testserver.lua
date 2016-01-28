local app = require(".")()

app:get("/", function(req, res)
    res:send("Hello, World!")
end)

app:start()

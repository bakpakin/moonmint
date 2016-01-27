local moonmint = require "moonmint"
local app = moonmint()

app:bind{}

app:get("/", function(req, res, go)
    res.code = 200
    res.body = "Hello, World!"
end)

app:start()

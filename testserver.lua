local moonmint = require(".")
local app = moonmint()

app:use(moonmint.util.logger, moonmint.static("."))

app:get("/", function(req, res)
    print("Raw Query: ", req.rawquery)
    res:send("Hello, World!")
end)

app:start()

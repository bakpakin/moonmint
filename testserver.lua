local moonmint = require("moonmint")
local app = moonmint()

app:use(moonmint.logger, moonmint.static("."))

app:get("/", function(req, res)
    print("Raw Query: ", req.rawQuery)
    res:send("Hello, World!")
end)

app:start()

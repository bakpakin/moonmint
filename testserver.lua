local moonmint = require("moonmint")
local app = moonmint()

app:use(moonmint.logger)

app:get("/", function(req, res)
    res:send("Hello, World!")
end)

app:use('/', moonmint.static {
    fallthrough = false
})

app:start()

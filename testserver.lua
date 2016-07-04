local moonmint = require("moonmint")
local util = moonmint.util
local app = moonmint()

-- app:use(moonmint.logger)
app:use(util.flexiResponse)

app:get("/", function(req)
    return "Hello, World!"
end)

app:use('/', moonmint.static {
    fallthrough = false
})

app:start()

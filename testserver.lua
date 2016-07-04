local moonmint = require("moonmint")
local util = moonmint.util
local app = moonmint()

app:use(util.logger)

app:get("/", "Hello, World!")

app:use('/', moonmint.static {
    fallthrough = false
})

app:start()

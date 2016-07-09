local moonmint = require("moonmint")
local util = moonmint.util
local app = moonmint()

app:use(util.logger)

app:use('/', moonmint.static {
    fallthrough = false
})

app:start()

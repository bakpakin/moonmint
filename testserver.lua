local moonmint = require("moonmint")
local util = moonmint.util
local app = moonmint()

app:use(util.logger)

app:get('/hi', function()
    return moonmint.agent {
        url = 'http://example.com'
    }
end)

app:use('/', moonmint.static {
    fallthrough = false
})

print(moonmint.agent {
    url = 'http://example.com'
}.body)

app:start()

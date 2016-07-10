local moonmint = require("moonmint")
local util = moonmint.util
local app = moonmint()

app:use(util.logger)

app:use('/', moonmint.static {
    fallthrough = false
})

local google = moonmint.agent
    :get('https://www.google.com/search')
    :blueprint()

function google:search(query)
    return self:param('q', query):param('oq', query)()
end

local res = google:search('hello')
print (res.body)

app:start()

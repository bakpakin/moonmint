local moonmint = require('moonmint')

local app = moonmint()

app:get('/', 'Hello, Lua 5.3')

app:start()

print "Hello, Lua 5.3!"

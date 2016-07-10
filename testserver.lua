local moonmint = require("moonmint")
local util = moonmint.util
local app = moonmint()

app:use(util.logger)

app:use('/', moonmint.static {
    base = arg[0],
    fallthrough = false,
    renderIndex = function(_, _, iter)
        local buffer = {'<!DOCTYPE html><html><head></head><body><ul>'}
        for item in iter do
            buffer[#buffer + 1] = ('<li>%s - %s</li>'):format(item.name, item.type)
        end
        buffer[#buffer + 1] = '</ul></body></html>'
        return moonmint.response(table.concat(buffer))
    end
})

print(arg[0])

app:start()

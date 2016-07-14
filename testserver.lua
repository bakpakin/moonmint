local moonmint = require("moonmint")
local util = moonmint.util
local app = moonmint()

app:use(util.logger)

app:use('/', moonmint.static {
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

app:bind {
    port = 8081,
    onStart = function() print('hi1') end
}

app:bind {
    port = 8082,
    onStart = function() print('hi2') end
}

local google = moonmint.agent
    :get('http://google.com/search')()

function google:search(query)
    return self():param('q', query):send().body
end

print(google:search('hi'))

app:start()

-- Expose the test function globally
test = require 'tools.oft'

local tests = {
    'html',
    'query',
    'simpleServer',
    'url'
}

local res = test(function()
    for i, v in ipairs(tests) do
        require('spec.' .. tests[i] .. '_spec')
    end
end)

-- Give a proper exit code for CI
os.exit(res.failed == 0 and 0 or 1)

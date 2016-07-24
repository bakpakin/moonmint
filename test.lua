
-- Expose the test function globally
test = require 'tools.oft'

local res = test(function()
    -- Get all of the files in the spec directory that end with
    -- '_spec' Use moonmint fs because we already have it
    local fs = require 'moonmint.fs'
    for item in fs.sync.scandir('spec') do
        if item.type == 'file' and item.name:match('^.*_spec%.lua$') then
            require('spec.' .. item.name:gsub('%.lua$', ''))
        end
    end
end)

-- Give a proper exit code for CI
os.exit(res.failed == 0 and 0 or 1)

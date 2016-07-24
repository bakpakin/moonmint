-- oft.lua
--
-- One Function Tests
--

-- Check if we are on windows. If so, check for ANSICON env variable
-- for color support. Otherwise, assume color support.
local cs = package.config:sub(1,1) ~= '\\'
if not cs then cs = os.getenv("ANSICON") end

-- Rendering

local RED = cs and '\27[31m' or ''
local GREEN = cs and '\27[32m' or ''
local RESET = cs and '\27[0m' or ''

local checkmark = '\226\156\147'
local xmark = '\226\156\151'

local greenCheck = RESET .. GREEN .. checkmark .. RESET

local function report(description, ok)
    if ok then
        return ('%s%s %s%s'):format(GREEN, checkmark, description, RESET)
    else
        return ('%s%s %s%s'):format(RED, xmark, description, RESET)
    end
end

local function progressStart(description)
    io.write('\n' .. description .. ' progress: ')
end

local function progress(ok, index)
    if ok then
        io.write(greenCheck)
    else
        io.write(('%s%s(%d)%s'):format(RESET, RED, index, RESET))
    end
end

local function progressEnd()
    print '\n'
end

local function renderLevel(ast, level)
    local res = ast.result
    local rep = report(res.description, res.status)
    print(string.rep('  ', level) .. rep)
    for i = 1, #ast do
        renderLevel(ast[i], level + 1)
    end
end

local function render(ast)
    renderLevel(ast, 0)
    local errors, numFailed, numPassed = ast.errors, ast.failed, ast.passed
    if #errors > 0 then
        print(('\n%s%d Errors: \n'):format(RED, #errors))
        for i = 1, #errors do
            print(i .. ': ' .. debug.traceback(errors[i]))
        end
    end
    print(('\n%s%d%s Failed, %s%d%s Passed.'):format(
        RED, numFailed, RESET,
        GREEN, numPassed, RESET))
end

-- Testing

local dynamicTest

local function test(description, fn, errors)
    if not fn then
        fn = description
        description = 'sub test'
    end
    local ast = {}
    local failed, passed = 0, 0
    local function subtest(desc, f)
        local ret = test(desc, f, errors)
        ast[#ast + 1] = ret
        passed = passed + ret.passed
        failed = failed + ret.failed
        return ret
    end
    local oldDyanmic = dynamicTest
    dynamicTest = subtest
    local ok, err = pcall(fn)
    dynamicTest = oldDyanmic
    local errorIndex = #errors + 1
    progress(ok, errorIndex)
    if not ok then
        errors[errorIndex] = err
    end
    ast.result = {
        description = description,
        status = ok,
        err = err
    }
    ast.passed = passed + (ok and 1 or 0)
    ast.failed = failed + (ok and 0 or 1)
    return ast
end

local function rootTest(description, fn)
    if not fn then
        fn = description
        description = 'root test'
    end
    local errors = {}
    progressStart(description)
    local results = test(description, fn, errors)
    progressEnd(description)
    results.errors = errors
    render(results)
    return results
end
dynamicTest = rootTest

return function(...)
    return dynamicTest(...)
end

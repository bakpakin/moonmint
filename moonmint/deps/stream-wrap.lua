local corunning = coroutine.running

local function makeCloser(socket)
    local closer = {
        read = false,
        written = false,
        errored = false,
    }

    local closed = false

    local function close()
        if closed then return end
        closed = true
        if not closer.readClosed then
            closer.readClosed = true
            if closer.onClose then
                closer.onClose()
            end
        end
        if not socket:is_closing() then
            socket:close()
        end
    end

    closer.close = close

    function closer.check()
        if closer.errored or (closer.read and closer.written) then
            return close()
        end
    end

    return closer
end

local unpack = table.unpack or unpack

local function makeRead(socket, closer)
    local paused = true
    local queue = {}
    local tindex = 0
    local dindex = 0
    local function dispatch(data)
        if tindex > dindex then
            local thread = queue[dindex]
            queue[dindex] = nil
            dindex = dindex + 1
            assert(coroutine.resume(thread, unpack(data)))
        else
            queue[dindex] = data
            dindex = dindex + 1
            if not paused then
                paused = true
                assert(socket:read_stop())
            end
        end
    end
    closer.onClose = function ()
        if not closer.read then
            closer.read = true
            return dispatch {nil, closer.errored}
        end
    end
    local function onRead(err, chunk)
        if err then
            closer.errored = err
            return closer.check()
        end
        if not chunk then
            if closer.read then return end
            closer.read = true
            dispatch {}
            return closer.check()
        end
        return dispatch {chunk}
    end
    return function()
        if dindex > tindex then
            local data = queue[tindex]
            queue[tindex] = nil
            tindex = tindex + 1
            return unpack(data)
        end
        queue[tindex] = corunning()
        tindex = tindex + 1
        if paused then
            paused = false
            assert(socket:read_start(onRead))
        end
        return coroutine.yield()
    end
end

local function makeWrite(socket, closer)
    local function wait()
        local thread = corunning()
        return function (err)
            assert(coroutine.resume(thread, err))
        end
    end
    return function(chunk)
        if closer.written then
            return nil, "already shutdown"
        end
        if chunk == nil then
            closer.written = true
            closer.check()
            socket:shutdown(wait())
            return coroutine.yield()
        end
        local success, err = socket:write(chunk, wait())
        if not success then
            closer.errored = err
            closer.check()
            return nil, err
        end
        err = coroutine.yield()
        return not err, err
    end
end

return function(socket)
    assert(socket
    and socket.write
    and socket.shutdown
    and socket.read_start
    and socket.read_stop
    and socket.is_closing
    and socket.close)

    local closer = makeCloser(socket)
    local read = makeRead(socket, closer)
    local write = makeWrite(socket, closer)
    return read, write, closer.close
end

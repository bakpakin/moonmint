--[[
Copyright (c) 2016 Calvin Rose
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- A filesystem abstraction on top of luv. Uses non-blocking coroutines
-- when available, otherwise uses blocking calls.
--
-- Modified from https://github.com/luvit/lit/blob/master/deps/coro-fs.lua

local uv = require 'luv'
local pathJoin = require('moonmint.deps.pathjoin').pathJoin

local fs = {}
local cocreate = coroutine.create
local coresume = coroutine.resume
local corunning = coroutine.running
local coyield = coroutine.yield

local function noop() end

local function makeCallback()
    local thread = corunning()
    if thread and uv.loop_alive() then -- Non Blocking callback (coroutines)
        return function (err, value, ...)
            if err then
                assert(coresume(thread, nil, err))
            else
                assert(coresume(thread, value == nil and true or value, ...))
            end
        end
    else -- Blocking callback
        local context = {}
        return function (err, first, ...)
            context.err = err
            context.first = first
            context.values = {...}
        end, context
    end
end

local unpack = unpack or table.unpack
local function tryYield(context)
    if context then -- Blocking
        uv.run("once") -- Should we use the defualt event loop?
        local err = context.err
        local first = context.first
        if err then
            return nil, err
        else
            return first == nil and true or first, unpack(context.values)
        end
    else -- Non blocking
        return coyield()
    end
end

function fs.mkdir(path, mode)
    local cb, context = makeCallback()
    uv.fs_mkdir(path, mode or 511, cb)
    return tryYield(context)
end

function fs.open(path, flags, mode)
    local cb, context = makeCallback()
    uv.fs_open(path, flags or "r", mode or 428, cb)
    return tryYield(context)
end

function fs.unlink(path)
    local cb, context = makeCallback()
    uv.fs_unlink(path, cb)
    return tryYield(context)
end

function fs.stat(path)
    local cb, context = makeCallback()
    uv.fs_stat(path, cb)
    return tryYield(context)
end

function fs.lstat(path)
    local cb, context = makeCallback()
    uv.fs_lstat(path, cb)
    return tryYield(context)
end

function fs.fstat(fd)
    local cb, context = makeCallback()
    uv.fs_fstat(fd, cb)
    return tryYield(context)
end

function fs.chmod(path)
    local cb, context = makeCallback()
    uv.fs_chmod(path, cb)
    return tryYield(context)
end

function fs.fchmod(path)
    local cb, context = makeCallback()
    uv.fs_fchmod(path, cb)
    return tryYield(context)
end

function fs.read(fd, length, offset)
    local cb, context = makeCallback()
    uv.fs_read(fd, length or 1024 * 48, offset or -1, cb)
    return tryYield(context)
end

function fs.write(fs, data, offset)
    local cb, context = makeCallback()
    uv.fs_write(fd, data, offset or -1, cb)
    return tryYield(context)
end

function fs.close(fd)
    local cb, context = makeCallback()
    uv.fs_close(fd, cb)
    return tryYield(context)
end

function fs.symlink(target, path)
    local cb, context = makeCallback()
    uv.fs_symlink(target, path, cb)
    return tryYield(context)
end

function fs.readlink(path)
    local cb, context = makeCallback()
    uv.fs_readlink(path, cb)
    return tryYield(context)
end

function fs.access(path, flags)
    local cb, context = makeCallback()
    uv.fs_access(path, flags or '', cb)
    return tryYield(context)
end

function fs.rmdir(path)
    local cb, context = makeCallback()
    uv.fs_rmdir(path, cb)
    return tryYield(context)
end

function fs.rmrf(path)
    local success, err = fs.rmdir(path)
    if success then
        return success, err
    end
    if err:match('^ENOTDIR:') then return fs.unlink(path) end
    if not err:match('^ENOTEMPTY:') then return success, err end
    for entry in assert(fs.scandir(path)) do
        local subPath = pathJoin(path, entry.name)
        if entry.type == 'directory' then
            success, err = fs.rmrf(pathJoin(path, entry.name))
        else
            success, err = fs.unlink(subPath)
        end
        if not success then return success, err end
    end
    return fs.rmdir(path)
end

function fs.scandir(path)
    local cb, context = makeCallback()
    uv.fs_scandir(path, cb)
    local req, err = tryYield(context)
    if not req then return nil, err end
    return function ()
        local name, typ = uv.fs_scandir_next(req)
        if not name then return name, typ end
        if type(name) == "table" then return name end
        return {
            name = name,
            type = typ
        }
    end
end

function fs.readFile(path)
    local fd, stat, data, err
    fd, err = fs.open(path)
    if err then return nil, err end
    stat, err = fs.fstat(fd)
    if stat then
        data, err = fs.read(fd, stat.size)
    end
    uv.fs_close(fd, noop)
    return data, err
end

function fs.writeFile(path, data, mkdir)
    local fd, success, err
    fd, err = fs.open(path, "w")
    if err then
        if mkdir and string.match(err, "^ENOENT:") then
            success, err = fs.mkdirp(pathJoin(path, ".."))
            if success then return fs.writeFile(path, data) end
        end
        return nil, err
    end
    success, err = fs.write(fd, data)
    uv.fs_close(fd, noop)
    return success, err
end

function fs.mkdirp(path, mode)
    local success, err = fs.mkdir(path, mode)
    if success or string.match(err, "^EEXIST") then
        return true
    end
    if string.match(err, "^ENOENT:") then
        success, err = fs.mkdirp(pathJoin(path, ".."), mode)
        if not success then return nil, err end
        return fs.mkdir(path, mode)
    end
    return nil, err
end

function fs.chroot(base)
    local chroot = {
        base = base,
        fstat = fs.fstat,
        fchmod = fs.fchmod,
        read = fs.read,
        write = fs.write,
        close = fs.close,
    }
    local function resolve(path)
        assert(path, "path missing")
        return pathJoin(base, pathJoin(path))
    end
    function chroot.mkdir(path, mode)
        return fs.mkdir(resolve(path), mode)
    end
    function chroot.mkdirp(path, mode)
        return fs.mkdirp(resolve(path), mode)
    end
    function chroot.open(path, flags, mode)
        return fs.open(resolve(path), flags, mode)
    end
    function chroot.unlink(path)
        return fs.unlink(resolve(path))
    end
    function chroot.stat(path)
        return fs.stat(resolve(path))
    end
    function chroot.lstat(path)
        return fs.lstat(resolve(path))
    end
    function chroot.symlink(target, path)
        -- TODO: should we resolve absolute target paths or treat it as opaque data?
        return fs.symlink(target, resolve(path))
    end
    function chroot.readlink(path)
        return fs.readlink(resolve(path))
    end
    function chroot.chmod(path, mode)
        return fs.chmod(resolve(path), mode)
    end
    function chroot.access(path, flags)
        return fs.access(resolve(path), flags)
    end
    function chroot.rename(path, newPath)
        return fs.rename(resolve(path), resolve(newPath))
    end
    function chroot.rmdir(path)
        return fs.rmdir(resolve(path))
    end
    function chroot.rmrf(path)
        return fs.rmrf(resolve(path))
    end
    function chroot.scandir(path, iter)
        return fs.scandir(resolve(path), iter)
    end
    function chroot.readFile(path)
        return fs.readFile(resolve(path))
    end
    function chroot.writeFile(path, data, mkdir)
        return fs.writeFile(resolve(path), data, mkdir)
    end
    return chroot
end

return fs

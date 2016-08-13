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

--- Abstractions around the libuv filesystem.
-- @module moonmint.fs
-- @author Calvin Rose
-- @copyright 2016
-- @license MIT

local uv = require 'luv'
local pathJoin = require('moonmint.deps.pathjoin').pathJoin

local fs = {}

local corunning = coroutine.running
local coresume = coroutine.resume
local coyield = coroutine.yield

local function noop() end

local function makeCallback(sync)
    local thread = corunning()
    if thread and not sync then -- Non Blocking callback (coroutines)
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
            context.done = true
            context.err = err
            context.first = first
            context.values = {...}
        end, context
    end
end

local unpack = unpack or table.unpack
local function tryYield(context)
    if context then -- Blocking
        while not context.done do
            uv.run('once') -- Should we use the default event loop?
        end
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

--- Wrapper around uv.fs_mkdir
function fs.mkdir(sync, path, mode)
    local cb, context = makeCallback(sync)
    uv.fs_mkdir(path, mode or 511, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_open
function fs.open(sync, path, flags, mode)
    local cb, context = makeCallback(sync)
    uv.fs_open(path, flags or "r", mode or 428, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_unlink
function fs.unlink(sync, path)
    local cb, context = makeCallback(sync)
    uv.fs_unlink(path, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_stat
function fs.stat(sync, path)
    local cb, context = makeCallback(sync)
    uv.fs_stat(path, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_lstat
function fs.lstat(sync, path)
    local cb, context = makeCallback(sync)
    uv.fs_lstat(path, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_fstat
function fs.fstat(sync, fd)
    local cb, context = makeCallback(sync)
    uv.fs_fstat(fd, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_chmod
function fs.chmod(sync, path)
    local cb, context = makeCallback(sync)
    uv.fs_chmod(path, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_fchmod
function fs.fchmod(sync, path)
    local cb, context = makeCallback(sync)
    uv.fs_fchmod(path, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_read
function fs.read(sync, fd, length, offset)
    local cb, context = makeCallback(sync)
    uv.fs_read(fd, length or 1024 * 48, offset or -1, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_write
function fs.write(sync, fd, data, offset)
    local cb, context = makeCallback(sync)
    uv.fs_write(fd, data, offset or -1, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_close
function fs.close(sync, fd)
    local cb, context = makeCallback(sync)
    uv.fs_close(fd, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_symlink
function fs.symlink(sync, target, path)
    local cb, context = makeCallback(sync)
    uv.fs_symlink(target, path, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_readlink
function fs.readlink(sync, path)
    local cb, context = makeCallback(sync)
    uv.fs_readlink(path, cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_access
function fs.access(sync, path, flags)
    local cb, context = makeCallback(sync)
    uv.fs_access(path, flags or '', cb)
    return tryYield(context)
end

--- Wrapper around uv.fs_rmdir
function fs.rmdir(sync, path)
    local cb, context = makeCallback(sync)
    uv.fs_rmdir(path, cb)
    return tryYield(context)
end

--- Remove directories recursively like the UNIX command `rm -rf`.
function fs.rmrf(sync, path)
    local success, err = fs.rmdir(sync, path)
    if success then
        return success, err
    end
    if err:match('^ENOTDIR:') then return fs.unlink(sync, path) end
    if not err:match('^ENOTEMPTY:') then return success, err end
    for entry in assert(fs.scandir(sync, path)) do
        local subPath = pathJoin(path, entry.name)
        if entry.type == 'directory' then
            success, err = fs.rmrf(sync, pathJoin(path, entry.name))
        else
            success, err = fs.unlink(sync, subPath)
        end
        if not success then return success, err end
    end
    return fs.rmdir(sync, path)
end

--- Smart wrapper around uv.fs_scandir.
-- @treturn function an iterator over file objects
-- in a directory. Each file table has a `name` property
-- and a `type` property.
function fs.scandir(sync, path)
    local cb, context = makeCallback(sync)
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

--- Reads a file into a string
function fs.readFile(sync, path)
    local fd, stat, data, err
    fd, err = fs.open(sync, path)
    if err then return nil, err end
    stat, err = fs.fstat(sync, fd)
    if stat then
        data, err = fs.read(sync, fd, stat.size)
    end
    uv.fs_close(fd, noop)
    return data, err
end

--- Writes a string to a file. Overwrites the file
-- if it already exists.
function fs.writeFile(sync, path, data, mkdir)
    local fd, success, err
    fd, err = fs.open(sync, path, "w")
    if err then
        if mkdir and err:match("^ENOENT:") then
            success, err = fs.mkdirp(sync, pathJoin(path, ".."))
            if success then return fs.writeFile(sync, path, data) end
        end
        return nil, err
    end
    success, err = fs.write(sync, fd, data)
    uv.fs_close(fd, noop)
    return success, err
end

--- Append a string to a file.
function fs.appendFile(sync, path, data, mkdir)
    local fd, success, err
    fd, err = fs.open(sync, path, "w+")
    if err then
        if mkdir and err:match("^ENOENT:") then
            success, err = fs.mkdirp(sync, pathJoin(path, ".."))
            if success then return fs.appendFile(sync, path, data) end
        end
        return nil, err
    end
    success, err = fs.write(sync, fd, data)
    uv.fs_close(fd, noop)
    return success, err
end

--- Make directories recursively. Similar to the UNIX `mkdir -p`.
function fs.mkdirp(sync, path, mode)
    local success, err = fs.mkdir(sync, path, mode)
    if success or err:match("^EEXIST") then
        return true
    end
    if err:match("^ENOENT:") then
        success, err = fs.mkdirp(sync, pathJoin(path, ".."), mode)
        if not success then return nil, err end
        return fs.mkdir(sync, path, mode)
    end
    return nil, err
end

-- Make sync and async versions
local function makeAliases(module)
    local ret = {}
    local ext = {}
    local sync = {}
    for k, v in pairs(module) do
        if type(v) == 'function' then
            if k == 'chroot' then
                sync[k], ext[k], ret[k] = v, v, v
            else
                sync[k] = function(...)
                    return v(true, ...)
                end
                ext[k] = v
                ret[k] = function(...)
                    return v(false, ...)
                end
            end
        end
    end
    ret.s = sync
    ret.sync = sync
    ret.ext = ext
    return ret
end

--- Creates a clone of fs, but with a different base directory.
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
    function chroot.mkdir(sync, path, mode)
        return fs.mkdir(sync, resolve(path), mode)
    end
    function chroot.mkdirp(sync, path, mode)
        return fs.mkdirp(sync, resolve(path), mode)
    end
    function chroot.open(sync, path, flags, mode)
        return fs.open(sync, resolve(path), flags, mode)
    end
    function chroot.unlink(sync, path)
        return fs.unlink(sync, resolve(path))
    end
    function chroot.stat(sync, path)
        return fs.stat(sync, resolve(path))
    end
    function chroot.lstat(sync, path)
        return fs.lstat(sync, resolve(path))
    end
    function chroot.symlink(sync, target, path)
        -- TODO: should we resolve absolute target paths or treat it as opaque data?
        return fs.symlink(sync, target, resolve(path))
    end
    function chroot.readlink(sync, path)
        return fs.readlink(sync, resolve(path))
    end
    function chroot.chmod(sync, path, mode)
        return fs.chmod(sync, resolve(path), mode)
    end
    function chroot.access(sync, path, flags)
        return fs.access(sync, resolve(path), flags)
    end
    function chroot.rename(sync, path, newPath)
        return fs.rename(sync, resolve(path), resolve(newPath))
    end
    function chroot.rmdir(sync, path)
        return fs.rmdir(sync, resolve(path))
    end
    function chroot.rmrf(sync, path)
        return fs.rmrf(sync, resolve(path))
    end
    function chroot.scandir(sync, path)
        return fs.scandir(sync, resolve(path))
    end
    function chroot.readFile(sync, path)
        return fs.readFile(sync, resolve(path))
    end
    function chroot.writeFile(sync, path, data, mkdir)
        return fs.writeFile(sync, resolve(path), data, mkdir)
    end
    function chroot.appendFile(sync, path, data, mkdir)
        return fs.appendFile(sync, resolve(path), data, mkdir)
    end
    function chroot.chroot(sync, newBase)
        return fs.chroot(sync, resolve(newBase))
    end
    return makeAliases(chroot)
end

return makeAliases(fs)

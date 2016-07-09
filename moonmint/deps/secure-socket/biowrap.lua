--[[

Copyright 2016 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local openssl = require('openssl')

-- writeCipher is called when ssl needs something written on the socket
-- handshakeComplete is called when the handhake is complete and it's safe
-- onPlain is called when plaintext comes out.
return function (ctx, isServer, socket, handshakeComplete)

  local bin, bout = openssl.bio.mem(8192), openssl.bio.mem(8192)
  local ssl = ctx:ssl(bin, bout, isServer)

  local ssocket = {tls=true}
  local onPlain

  local function flush(callback)
    local chunks = {}
    local i = 0
    while bout:pending() > 0 do
      i = i + 1
      chunks[i] = bout:read()
    end
    if i == 0 then
      if callback then callback() end
      return true
    end
    return socket:write(chunks, callback)
  end

  local function handshake(callback)
    if ssl:handshake() then
      local success, result = ssl:getpeerverification()
      socket:read_stop()
      if not success and result then
        handshakeComplete("Error verifying peer: " .. result[1].error_string)
      end
      handshakeComplete(nil, ssocket)
    end
    return flush(callback)
  end

  local function onCipher(err, data)
    if not onPlain then
      if err or not data then
        return handshakeComplete(err or "Peer aborted the SSL handshake", data)
      end
      bin:write(data)
      return handshake()
    end
    if err or not data then
      return onPlain(err, data)
    end
    bin:write(data)
    while  true do
      local plain = ssl:read()
      if not plain then break end
      onPlain(nil, plain)
    end
  end

  -- When requested to start reading, start the real socket and setup
  -- onPlain handler
  function ssocket.read_start(_, onRead)
    onPlain = onRead
    return socket:read_start(onCipher)
  end

  -- When requested to write plain data, encrypt it and write to socket
  function ssocket.write(_, plain, callback)
    ssl:write(plain)
    return flush(callback)
  end

  function ssocket.shutdown(_, ...)
    return socket:shutdown(...)
  end
  function ssocket.read_stop(_, ...)
    return socket:read_stop(...)
  end
  function ssocket.is_closing(_, ...)
    return socket:is_closing(...)
  end
  function ssocket.close(_, ...)
    return socket:close(...)
  end

  handshake()
  socket:read_start(onCipher)

end

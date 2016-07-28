# moonmint

NOTE: moonmint is a Work In Progress. API is not stable.

![Travis](https://travis-ci.org/bakpakin/moonmint.svg?branch=master)

__moonmint__ is an HTTP web framework for Lua.
Use complex routing, static file serving, and templating with a
minimal code base. Harness the power of libuv to perform asynchronous operations.

Check out the [wiki](https://github.com/bakpakin/moonmint/wiki) for more information.

## Features

* Simple and flexible express-like routing
* Middleware
* Static file server
* Nonblocking operations with coroutines and libuv
* Supports Lua 5.2, 5.3, LuaJIT 2.0, LuaJIT 2.1
* Powerful asynchronous agent for making HTTP requests
* Templating engine

## Quick Install

In order to install moonmint, the following dependencies are needed.

* Luarocks (the package manager)
* OpenSSL (for the bkopenssl dependecy)
* CMake (for the luv libuv binding)

Also, make sure that the Lua dev packages are installed on linux.
On OSX using brew openssl, you may need to provide the openssl
directory to luarocks to install bkopenssl.

Use luarocks to install
```
luarocks install --server=http://luarocks.org/dev moonmint
```

See the wiki for more information.

## Example

moonmint is really simple - probably the simplest way to get a running webserver in Lua out there!
Install with luarocks,  write your server script, and run it!
The following example servers serve "Hello, World!" on the default port 8080.

```lua
local moonmint = require 'moonmint'
local app = moonmint()

app:get("/", 'Hello, World!')

app:start()
```

This can be even shorter if you use chaining.

```lua
require('moonmint')()
    :get('/', 'Hello, World!')
    :start()
```
## Credits

A lot of code was modified from the [Luvit](https://luvit.io/) project and from [Tim Caswell](https://twitter.com/creationix), the main author.
moonmint depends on the luv library, a Lua binding to libuv.

Another important dependency is lua-openssl, which is a very useful openssl binding for Lua created and maintained
by [George Zhao](https://github.com/zhaozg). Many thanks.

## License

MIT

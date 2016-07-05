# moonmint

![Travis](https://travis-ci.org/bakpakin/moonmint.svg?branch=master)

__moonmint__ is an HTTP web framework for Lua.
Use complex routing, static file serving, and templating with a
minimal code base. Harness the power of libuv to perform asynchronous operations.

Check out the [wiki](https://github.com/bakpakin/moonmint/wiki) for more information.

## Features

* Simple and flexible express-like routing
* Middleware
* Static file server
* Asynchronous operation
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
luarocks install moonmint
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
## License

MIT

# moonmint

![Travis](https://travis-ci.org/bakpakin/moonmint.svg?branch=master)

__moonmint__ is an HTTP web framework for Lua.
Use complex routing, static file serving, and templating with a
minimal code base. Harness the power of libuv to perform asynchronous operations.

## Features

* Simple and flexible express-like routing
* Middleware
* Static file server
* Asynchronous operation
* Templating engine

## Example

moonmint is really simple - probably the simplest way to get a running webserver in Lua out there!
Install with luarocks,  write your server script, and run it!
The following example servers serve "Hello, World!" on the default port 8080.

```lua
local moonmint = require 'moonmint'
local app = moonmint()

app:get("/", function(req)
    res:send("Hello, World!")
end)

app:start()
```

This can be even shorter if you use chaining and short syntax for sending strings.

```lua
require('moonmint')()
    :get('/', 'Hello, World!')
    :start()
```

### Templates

Templates are pretty simple - They are fancy string constructors that
work well with html (HTML escaped). You can insert variable text into
the templates via inserts.

```lua
local template = moonmint.template('Hello, {{currentUser}}!')

local str = template {
    currentUser = 'Joe'
}

print(str)
-- Prints 'Hello, Joe!'
```

The first is basic text substitution with double
brackets `{{ }}`.

```html
<html>
<body>
    {{&innerStuff}}
    <div class="myfooter">
        {{footer}}
    </div>
</body>
</html>
```

This does plain text substitution into the HTML document. It also escapes the HTML for safe insertion. To not
escape the HTML, prefix with the '&' symbol. In the above example, `innerStuff` is not HTML escaped.

One can also inject Lua into the template functions, which are compiled into Lua and loaded via `loadstring`.
Lua is inject inside percent brackets `{% %}`. To access the argument passed to the template, reference the
`content` variable.

```html
<html>
<body>

    {% if content.user ~= 'Joe' then %}
        {{inner}}
    {% end %}

    <div class="myfooter">
        {{footer}}
    </div>
</body>
</html>
```

Lastly, one can inject comments into the template via hash brackets `{# #}`. Everything inside the brackets and the brackets
themselves is ignored.

Whitespace trimming is also available. To trim whitespace from before a template insert, add a ''-' symbol
at the beginning of the insert. To trim from the end, add a '-' symbol to the end of the insert.

```html
<html>
<body>

    {# This is a comment #}

    {% if content.user ~= 'Joe' then %}
        {# Whitespace is trimmed form both before and after 'inner' #}
        {{inner}}
    {% end %}

    <div class="myfooter">
        {{footer}}
    </div>
</body>
</html>
```

### Files

moonmint provides an abstraction around the libuv filesystem that is non blocking. It is based
on Tim Caswell's [coro-fs](https://github.com/luvit/lit/blob/master/deps/coro-fs.lua), although it has been modified to work synchronously outside of the
libuv event loop and coroutines. Essentially, you can always use simple syntax to read and write
to the filesystem, but get awesome asynchronous behavior when you need it.

```lua
local moonmint = require 'moonmint'
local app = moonmint()
local fs = moonmint.fs

-- Outside of libuv event loop - synchronous
local indexHtml = fs.readFile('myIndex.html')

app:get('/', function (req, res)
	res:send(indexHtml)
end)

app:get('/dynamic', function (req, res)
	-- Inside uv event loop - asynchronous
	local data, err = fs.readFile('myChangingPage.html')
	res:send(data)
end)

app:start()
```
The moonmint fs module supports the same operations as coro-fs. The operations
are for the most part asynchronous wrappers around the libuv functions, with
a few goodies thrown in link `fs.rmrf` and `fs.mkdirp`.

* `fs.mkdir`
* `fs.open`
* `fs.unlink`
* `fs.stat`
* `fs.lstat`
* `fs.fstat`
* `fs.chmod`
* `fs.fchmod`
* `fs.read`
* `fs.write`
* `fs.close`
* `fs.symlink`
* `fs.readlink`
* `fs.access`
* `fs.rmdir`
* `fs.rmrf`
* `fs.scandir`
* `fs.readFile`
* `fs.writeFile`
* `fs.mkdirp`
* `fs.chroot`

## Install
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

## License

MIT

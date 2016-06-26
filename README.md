# moonmint

__moonmint__ is an express like web framework for Lua.
Use complex routing, static file serving, and templating with an extremely
minimal code base. Uses the libuv binding luv to perform asynchronous operations.

## Contents

### [Example](#example)

### [API](#api)

* [Fields](#fields)
* [Functions](#functions)
* [Types](#types)
  * [Server](#server)
    * [Methods](#methods)
  * [Router](#router)
    * [Fields](#fields-1)
    * [Methods](#methods-1)
  * [Request](#request)
    * [Fields](#fields-2)
    * [Methods](#methods-2)
  * [Response](#response)
    * [Fields](#fields-3)
    * [Methods](#methods-3)
* [Templates](#templates)
* [Files](#files)

### [Install](#install)

## Example

```lua
local moonmint = require 'moonmint'
local app = moonmint()

app:use(moonmint.logger, moonmint.static("."))

app:get("/", function(req, res)
    print("Raw Query: ", req.rawQuery)
    res:send("Hello, World!")
end)

app:start()
```

## API

### Fields

* `moonmint.bodyParser` - Parses the body of incoming requests, and stores the resulting string in `Request.body`.
* `moonmint.queryParser` - Parses the raw query string of incoming requests, and stores the resulting object in `Request.query`.
* `moonmint.logger` - A useful default logging middleware.

### Functions

* `moonmint.server()` - Creates a new Server. Also exposed as `moonmint()`.
* `moonmint.router([options])` - Creates a new Router. Options:
  * `mergeParams` - See Router fields.
  * `mergeName` - See Router fields.
* `moonmint.static(options)` - Creates a new static file server sub-app with options. The `options` parameter
  is a table, and the following options are supported.
  * `base` - The root path on disk to serve files from. Defaults to '.'.
  * `nocache` - A boolean that will disable caching if truthy.
* `moonmint.template(source)` - Creates a new template function from a string. If the template source cannot be
  parsed, then returns nil and an error as the second parameter. See the Templates section for more info.

### Utility Functions

* `moonmint.queryEncode(obj)` - Encodes a Lua object as a url query string.
* `moonmint.queryDecode(str)` - Decodes a query string into a Lua table.
* `moonmint.urlEncode(str)` - Encodes a Lua string into a url safe string.
* `moonmint.urlDecode(str)` - Decodes a url string into a Lua string.
* `moonmint.htmlEscape(str)` - Escapes a string for safe input into an HTML page.
* `moonmint.htmlUnescape(str)` - Unescape text from HTML.
* `moonmint.uuidv4()` - Creates a new random UUID v4.

### Types

#### Server

The main moonmint object used construct a moonmint app. All Server methods return the server to allow for chaining.

##### Methods

* `Server:bind([options])` - Creates a binding for the server. Options:
  * `host`: The host to bind to. Default is `0.0.0.0`.
  * `port`: The port to bind to. If running as root, the default ports are 80 for HTTP and 443 for HTTPS. Otherwise,
    the defaults are 8080 for HTTP and 8443 for HTTPS.
  * `tls`: An optional table used to enable SSL. Should contain `key` and `cert`, the SSL credentials as strings.
  * `onStart`: An optional callback that is called when the Server starts.
* `Server:start()` - Starts the server on all bindings. Returns the Server.
* `Server:static(realpath, urlpath)`

All servers contain a main Router. The Router's methods are aliased to the server, so one
can call `server:use(mw)` or `server:get('/', handler)`.

#### Router

A special handler that routes requests. It is implemented as a middleware, so it is callable with
the middleware function signature, `myRouter(req, res, go)`.

Routes support express-like syntax. Use normal URL paths, or use captures to match many paths.
To capture a path element, use the colon syntax '/path/:capturename/more'. The URL section that matched
capturename will be available in `Request.params.capturename`. To match multiple sections of a URL, use
double colon syntax - '/path/:capturemany:/more'.

##### Fields

* `Router.mergeParams` - Whether or not to merge matched parameters into `Request.params`. Default is true.
* `Router.mergeName` - If set and mergeParams is true, then merge the parameters into `Request.params[mergeName]`
  instead of the default path. Default is nil.

##### Methods

All Router methods return the Router for chaining.

* `Router:use([route], ...)` - Uses middleware under the optional route. Multiple middleware can be chained for use
  in series. Middleware functions follow the express-connect signature of `middleware(req, res, go)`. The `req`
  parameter is the Request, the `res` parameter is the response, and `go` calls the next middleware in the chain.
* `Router:route(options, ...)` - Uses middleware on requests that match the `options` table. Options:
	* `path` - The route string or function used to match request paths.
	* `host` - A Lua pattern or function used to match the request host.
	* `method` - A string, table, or function to match an HTTP verb. Use '*' to match all. Use a list-like table of HTTP verbs
	  to match a set of verbs.
* `Router:all(route, ...)` - Route alias for '*'.
* `Router:get(route, ...)` - Route alias for 'GET'.
* `Router:put(route, ...)` - Route alias for 'PUT'.
* `Router:post(route, ...)` - Route alias for 'POST'.
* `Router:delete(route, ...)` - Route alias for 'DELETE'.
* `Router:head(route, ...)` - Route alias for 'HEAD'.
* `Router:options(route, ...)` - Route alias for 'OPTIONS'.
* `Router:trace(route, ...)` - Route alias for 'TRACE'.
* `Router:connect(route, ...)` - Route alias for 'CONNECT'.

#### Request

Represents an HTTP request. Constructed for every connection by the Server.

##### Fields

* `Request.app` - The moonmint app that created this Request.
* `Request.socket` - The raw luv (libuv) socket.
* `Request.method` - The HTTP verb of the Request.
* `Request.url` - The full URL of the original request.
* `Request.path` - The path part of the url. Will be modified in sub routers.
* `Request.originalPath` - The original path part of the url.
* `Request.rawQuery` - The raw query string extract from the URL.
* `Request.headers` - A read and write table of headers.
* `Request.keepAlive` - Boolean that indicates a keep-alive connection.
* `Request.body` - The body of the request. Only available after the middleware `moonmint.bodyParse`.

##### Methods

* `Request:get(header)` - Gets a header.

#### Response

Represents an HTTP response. Constructed for every connection by the Server.

##### Fields

* `Response.app` - The moonmint app that created this response.
* `Response.code` - The status co de of the Response.
* `Response.socket` - The raw luv (libuv) socket.
* `Response.headers` - A table of headers that can be modified as needed.
* `Response.body` - The body of the Response.

##### Methods

All Response methods return the Response object, so the methods can be chained.

* `Response:set(header, value)` - Set a header.
* `Response:append(header, ...)` - Append to a header, creating it if it doesn't yet exist.
* `Response:get(header)` - Get a header value.
* `Response:send([body])` - Send the Response. Sets the body of the response optionally, and
  will use a status code of 200 if not otherwise specified.
* `Response:status(code)` - Set the status code of the Response.
* `Response:redirect(location)` - Sets the Response to an HTTP redirect response.

### Templates

Templates are pretty simple - They are fancy string constructors that
work well with html (HTML escaped). You can insert variable text into
the templates via inserts.

```lua
local template = moonmint.template('Hello, {{currentUser}}!')

local str = template {
    currentUser = 'Joe'
}
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

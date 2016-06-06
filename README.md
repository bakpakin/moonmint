# moonmint

## Contents

## Description
__moonmint__ is an express like web framework that runs on top of luvit and/or lit. 

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

* `moonmint.bodyParse` - Parses the body of incoming requests, and stores the resulting string in `Request.body`.
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
* `moonmint.queryEncode(obj)` - Encodes a Lua object as a url query string. 
* `moonmint.queryDecode(str)` - Decodes a query string into a Lua table.
* `moonmint.urlEncode(str)` - Encodes a Lua string into a url safe string.
* `moonmint.urlDecode(str)` - Decodes a url string into a Lua string.
* `moonmint.htmlEscape(str)` - Escapes a string for safe input into an HTML page.
* `moonmint.htmlUnescape(str)` - Unescape text from HTML.

### Types

#### Server

The main moonmint object used construct a moonmint app. All Server methods return the server to allow for chaining.

* `Server:bind([options])` - Creates a binding for the server. The `options` parameter should
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

* `Response:set(header, value)` - Set a header.
* `Response:append(header, ...)` - Append to a header, creating it if it doesn't yet exist.
* `Response:get(header)` - Get a header value.
* `Response:send([body])` - Set the body of the Response.
* `Response:redirect(location)` - Sets the Response to an HTTP redirect response.

### Templates

Templates are pretty simple - They are fancy string constructors.

```lua
local template = moonmint.template('Hello, {{currentUser}}!')

local str = template {
    currentUser = 'Joe'
}
```

The first is basic text substitution with double 
brackets `{{ }}`.

```
<html>
<body>
    {{content}}
    <div class="myfooter">
        {{footer}}
    </div>
</body>
</html>
```

This does plain substitution into the HTML document. If rendering an HTML page with user input or other
not HTML input, use `moonmint.htmlEscape(str)` on 
the arguments to the template.

One can also inject Lua into the template functions, which are compiled into Lua and loaded via `loadstring`.
Lua is inject inside percent brackets `{% %}`. To access the argumnnet passed to the template, reference the
`content` variable.

```
<html>
<body>

    {% if content.user ~= 'Joe' %}
    {{content}}
    {% end %}

    <div class="myfooter">
        {{footer}}
    </div>
</body>
</html>
```

In the above example, the `{{content}}` arguments is not the same as `content` in the Lua part of the template.

Lastly, one can inject comments into the template via hash brackets `{# #}`. Everything inside the brackets and the brackets
themselves is ignored.

```
<html>
<body>

    {# This is a comment #}

    {% if content.user ~= 'Joe' %}
    {{content}}
    {% end %}

    <div class="myfooter">
        {{footer}}
    </div>
</body>
</html>
```

## Install
Download and install __lit__, and the install moonmint in your project directory.
```
lit install bakpakin/moonmint
```

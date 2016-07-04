# TODO

## Goals
* Make Travis builds pass
* Add testing for server code
* Add more testing in general
* Better documentation, preferably LuaDoc like (source generated) or on the wiki. Add docs as we go.
* Webdav HTTP methods - also make sure to set the HTTP version for those.
* Contributing guide
* AJAX style request agent with proper TLS support.
* Cookie utilities
* Etags, either only with static or as utility middleware (or both).
* View engine that is integrated with built in templates, but can eventually use others like etlua. Partials support.
* Add more general pattern support in routing.
* Websockets - easy to integrate and of course coro-style
* Get a logo!

## Maybe
* Compatibility with all modern Lua versions (5.1, 5.2, 5.3, LuaJIT). LuaJIT is currently the primary target.
* Pretty homepage.
* Full Windows compatibiliy
* Make moonmint run both as a Luarocks package, and as a luvit/lit module (backport to lit). Ensure that tests run on both platforms.
* Refactor dependent packages for easier building on platforms (remove CMake dependency?)
* CLI tool for project templates, packaging, and deploying.
* Tutorials and example projects.
* Useful addons and libraries like body parsing, database connectors, authentication, etc.

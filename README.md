# lua-utils
A collection of utilities I've built as-needed for progamming in Lua and working with [Hammerspoon](hammerspoon.org).

Utilities compatible with vanilla Lua 5.3 are at the top level, while those intended for working with and/or extending Hammerspoon core libraries are nested within the `hammerspoon` directory.

**NOTE:** If using any `hammerspoon` utilities, be sure to add the `lua-utils/?.lua` and `lua-utils/hammerspoon/?.lua` patterns to your `package.path`: some of the Hammerspoon utilities rely on the vanilla Lua ones.

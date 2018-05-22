# ModuleInterfaceTools

[![Build Status](https://travis-ci.org/JuliaString/ModuleInterfaceTools.jl.svg?branch=master)](https://travis-ci.org/JuliaString/ModuleInterfaceTools.jl)

[![Coverage Status](https://coveralls.io/repos/github/JuliaString/ModuleInterfaceTools.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaString/ModuleInterfaceTools.jl?branch=master)

[![codecov.io](http://codecov.io/github/JuliaString/ModuleInterfaceTools.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaString/ModuleInterfaceTools.jl?branch=master)

The `ModuleInterfaceTools` package is now working on both the release version (v0.6.2) and the latest master (v0.7.0-DEV).

This provides a way of having different lists of names that you want to be part of a public API,
as well as being part of a development API (i.e. functions that are not normally needed by users of a package, but *are* needed by a developer writing a package that depends on it).
It also separates lists of names of functions, that can be extended, from names of types, modules, constants that cannot be extended, and functions that are not intended to be extended.

This is a bit of a work-in-progress, I heartily welcome any suggestions for better syntax, better implementation, and extra functionality.

```julia
@api <cmd> [<symbols>...]

 * @api init             # set up module/package for adding names
 * @api freeze           # use at end of module, to "freeze" API

 * @api use    <modules>... # for normal use, i.e. `using`
 * @api test   <modules>... # using public and develop symbols, for testing purposes
 * @api extend <modules>... # for development, imports `base`, `public`, and `develop` lists,
 *                          # uses `define_public`and `define_develop` lists
 * @api export <modules>... # export api symbols

 * @api base   <names...>  # Add functions from Base that are part of the API
 * @api public <names...>  # Add functions that are part of the public API
 * @api develop <names...> # Add functions that are part of the development API
 * @api define_public <names...> # Add other symbols that are part of the public API (structs, consts)
 * @api define_develop <names...> # Add other symbols that are part of the development API
 * @api define_module <names...> # Add submodule names that are part of the API
 * @api maybe_public <names...>  # Conditionally import functions from Base, or define them
```

This also includes the `@def` macro, which I've found very useful!

I would also like to add commands that add the functionality of `@reexport`,
but instead of exporting the symbols found in the module(s), add them to either the public
or develop list. (I had a thought that it could automatically add names that do not start with `_`,
have a docstring, and are not exported, to the develop list, and all exported names would be added to the public list).

Another thing I'd like to add is a way of using/importing a module, but having pairs of names, for renaming purposes, i.e. something like `@api use Foobar: icantreadthisname => i_cant_read_this_name`
which would import the variable from Foobar, but with the name after the `=>`.

Finally, I'd like to add a few interactive commands, such as `@api list public`, or `@api list develop Foobar`, to display what the API is of the current module, or of the given module(s).

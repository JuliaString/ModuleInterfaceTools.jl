# ModuleInterfaceTools

[pkg-url]: https://github.com/JuliaString/ModuleInterfaceTools.jl.git

[julia-url]:    https://github.com/JuliaLang/Julia
[julia-release]:https://img.shields.io/github/release/JuliaLang/julia.svg

[release]:      https://img.shields.io/github/release/JuliaString/ModuleInterfaceTools.jl.svg
[release-date]: https://img.shields.io/github/release-date/JuliaString/ModuleInterfaceTools.jl.svg

[license-img]:  http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat
[license-url]:  LICENSE.md

[gitter-img]:   https://badges.gitter.im/Join%20Chat.svg
[gitter-url]:   https://gitter.im/JuliaString/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge

[ga-s-img]: https://img.shields.io/github/checks-status/JuliaString/ModuleInterfaceTools.jl
[ga-m-img]: https://img.shields.io/github/checks-status/JuliaString/ModuleInterfaceTools.jl/master

[codecov-url]:  https://codecov.io/gh/JuliaString/ModuleInterfaceTools.jl
[codecov-img]:  https://codecov.io/gh/JuliaString/ModuleInterfaceTools.jl/branch/master/graph/badge.svg

[contrib]:    https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat

[![][release]][pkg-url] [![][release-date]][pkg-url] [![][license-img]][license-url] [![contributions welcome][contrib]](https://github.com/JuliaString/ModuleInterfaceTools.jl/issues)

| **Julia Version** | **Unit Tests** | **Coverage** |
|:------------------:|:------------------:|:---------------------:|
| [![][julia-release]][julia-url] | [![][ga-s-img]][pkg-url] | [![][codecov-img]][codecov-url]
| Julia Latest | [![][ga-m-img]][pkg-url] | [![][codecov-img]][codecov-url]

This provides a way of having different lists of names that you want to be part of a public API,
as well as being part of a development API (i.e. functions that are not normally needed by users of a package, but *are* needed by a developer writing a package that depends on it).
It also separates lists of names of functions, that can be extended, from names of types, modules, constants that cannot be extended, and functions that are not intended to be extended.

This is a bit of a work-in-progress, I heartily welcome any suggestions for better syntax, better implementation, and extra functionality.

```julia
@api <cmd> [<symbols>...]

 * @api list                # display information about this module's API
 * @api freeze              # use at end of module, to "freeze" API

 * @api list   <modules>... # display information about one or more modules' API
 * @api use    <modules>... # for normal use, i.e. `using`
 * @api test   <modules>... # using public and develop symbols, for testing purposes
 * @api extend <modules>... # for development, imports `base`, `public`, and `develop` lists,
 *                          # uses `define_public`and `define_develop` lists
 * @api export <modules>... # export api symbols

 * @api base     <names...> # Add functions from Base that are part of the API
 * @api public!  <names...> # Add functions that are part of the public API
 * @api develop! <names...> # Add functions that are part of the development API
 * @api public   <names...> # Add other symbols that are part of the public API (structs, consts)
 * @api develop  <names...> # Add other symbols that are part of the development API
 * @api modules  <names...> # Add submodule names that are part of the API
 * @api base!    <names...> # Conditionally import functions from Base, or define them
```

This also includes the `@def` macro, renamed as `@api def` which I've found very useful!

I would also like to add commands that add the functionality of `@reexport`,
but instead of exporting the symbols found in the module(s), add them to either the public
or develop list. (I had a thought that it could automatically add names that do not start with `_`,
have a docstring, and are not exported, to the develop list, and all exported names would be added to the public list).

Another thing I'd like to add is a way of using/importing a module, but having pairs of names, for renaming purposes, i.e. something like `@api use Foobar: icantreadthisname => i_cant_read_this_name`
which would import the variable from Foobar, but with the name after the `=>`.


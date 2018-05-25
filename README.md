# ModuleInterfaceTools

| **Info** | **Windows** | **Linux & MacOS** | **Package Evaluator** | **CodeCov** | **Coveralls** |
|:------------------:|:------------------:|:---------------------:|:-----------------:|:---------------------:|:-----------------:|
| [![][license-img]][license-url] | [![][app-s-img]][app-s-url] | [![][travis-s-img]][travis-url] | [![][pkg-s-img]][pkg-s-url] | [![][codecov-img]][codecov-url] | [![][coverall-s-img]][coverall-s-url]
| [![][gitter-img]][gitter-url] | [![][app-m-img]][app-m-url] | [![][travis-m-img]][travis-url] | [![][pkg-m-img]][pkg-m-url] | [![][codecov-img]][codecov-url] | [![][coverall-m-img]][coverall-m-url]

[license-img]:  http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat
[license-url]:  LICENSE.md

[gitter-img]:   https://badges.gitter.im/Join%20Chat.svg
[gitter-url]:   https://gitter.im/JuliaString/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge

[travis-url]:   https://travis-ci.org/JuliaString/ModuleInterfaceTools.jl
[travis-s-img]: https://travis-ci.org/JuliaString/ModuleInterfaceTools.jl.svg
[travis-m-img]: https://travis-ci.org/JuliaString/ModuleInterfaceTools.jl.svg?branch=master

[app-s-url]:    https://ci.appveyor.com/project/ScottPJones/moduleinterfacetools-jl
[app-m-url]:    https://ci.appveyor.com/project/ScottPJones/moduleinterfacetools-jl/branch/master
[app-s-img]:    https://ci.appveyor.com/api/projects/status/x13gh7y6id3fbmke?svg=true
[app-m-img]:    https://ci.appveyor.com/api/projects/status/x13gh7y6id3fbmke/branch/master?svg=true

[pkg-s-url]:    http://pkg.julialang.org/detail/ModuleInterfaceTools
[pkg-m-url]:    http://pkg.julialang.org/detail/ModuleInterfaceTools
[pkg-s-img]:    http://pkg.julialang.org/badges/ModuleInterfaceTools_0.6.svg
[pkg-m-img]:    http://pkg.julialang.org/badges/ModuleInterfaceTools_0.7.svg

[codecov-url]:  https://codecov.io/gh/JuliaString/ModuleInterfaceTools.jl
[codecov-img]:  https://codecov.io/gh/JuliaString/ModuleInterfaceTools.jl/branch/master/graph/badge.svg

[coverall-s-url]: https://coveralls.io/github/JuliaString/ModuleInterfaceTools.jl
[coverall-m-url]: https://coveralls.io/github/JuliaString/ModuleInterfaceTools.jl?branch=master
[coverall-s-img]: https://coveralls.io/repos/github/JuliaString/ModuleInterfaceTools.jl/badge.svg
[coverall-m-img]: https://coveralls.io/repos/github/JuliaString/ModuleInterfaceTools.jl/badge.svg?branch=master

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


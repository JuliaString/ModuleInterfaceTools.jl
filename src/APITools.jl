__precompile__(true)
"""
API Tools package

Copyright 2018 Gandalf Software, Inc., Scott P. Jones
Licensed under MIT License, see LICENSE.md

(@def macro "stolen" from DiffEqBase.jl/src/util.jl :-) )
"""
module APITools
export @api, @def

macro def(name, definition)
    quote
        macro $(esc(name))()
            esc($(Expr(:quote, definition)))
        end
    end
end

struct TMP_API
    base::Vector{Symbol}
    public::Vector{Symbol}
    develop::Vector{Symbol}
    define_public::Vector{Symbol}
    define_develop::Vector{Symbol}
    TMP_API() = new(Symbol[], Symbol[], Symbol[], Symbol[], Symbol[])
end

const SymList = Tuple{Vararg{Symbol}}

struct API
    mod::Module
    base::SymList
    public::SymList
    develop::SymList
    define_public::SymList
    define_develop::SymList

    API(mod, api::TMP_API) =
        new(mod,
            SymList(api.base), SymList(api.public), SymList(api.develop),
            SymList(api.define_public), SymList(api.define_develop))
end

const APIList = Tuple{Vararg{API}}

"""
@api <cmd> [<symbols>...]

 * @api init             # set up module/package for adding names
 * @api freeze           # use at end of module, to "freeze" API

 * @api use    <modules>... # use for normal use
 * @api test   <modules>... # using api and dev, for testing purposes
 * @api extend <modules>... # for development, imports api & dev, use api & dev definitions
 * @api export <modules>... # export api symbols

 * @api base   <names...>  # Add functions from Base that are part of the API
 * @api public <names...>  # Add functions that are part of the public API
 * @api develop <names...> # Add functions that are part of the development API
 * @api define_public <names...> # Add other symbols that are part of the public API (structs, consts)
 * @api define_develop <names...> # Add other symbols that are part of the development API
"""
macro api(cmd::Symbol)
    if cmd == :init
        quote
            global __tmp_api__ = APITools.TMP_API()
            global __tmp_chain__ = Vector{APITools.API}[]
        end
    elseif cmd == :freeze
        @static if VERSION < v"0.7.0-DEV"
            esc(quote
                const __chain__ = APITools.APIList(__tmp_chain__)
                const __api__ = APITools.API(current_module(), __tmp_api__)
                __tmp_chain__ = _tmp_api__ = nothing
                end)
        else
            esc(quote
                const __chain__ = APITools.APIList(__tmp_chain__)
                const __api__ = APITools.API(@__MODULE__, __tmp_api__)
                __tmp_chain__ = _tmp_api__ = nothing
                end)
        end
    else
        error("@api unrecognized command: $cmd")
    end
end

const _cmdadd = (:define_public, :define_develop, :public, :develop, :base)
const _cmduse = (:use, :test, :extend, :export)

@static VERSION < v"0.7.0-DEV" && (const _ff = findfirst)
@static VERSION < v"0.7.0-DEV" ||
    (_ff(lst, val) = coalesce(findfirst(isequal(val), lst), 0))

function _add_symbols(grp, exprs)
    symbols = Symbol[]
    for ex in exprs
        if isa(ex, Expr) && ex.head == :tuple
            append!(symbols, ex.args)
        elseif isa(ex, Symbol)
            push!(symbols, ex)
        else
            error("@api $grp: syntax error $ex")
        end
    end
    esc(:( append!(__tmp_api__.$grp, $symbols) ))
end

function _make_modules(exprs)
    uselst = Expr[]
    modlst = Symbol[]
    for ex in exprs
        if isa(ex, Expr) && ex.head == :tuple
            append!(modlst, ex.args)
            for e in ex.args ; push!(uselst, :(using $sym)) ; end
        elseif isa(ex, Symbol)
            push!(modlst, ex)
            push!(uselst, :(using $ex))
        else
            error("@api $cmd: syntax error $ex")
        end
    end
    uselst, modlst
end

macro api(cmd::Symbol, exprs...)
    ind = _ff(_cmdadd, cmd)
    ind == 0 || return _add_symbols(cmd, exprs)

    ind = _ff(_cmduse, cmd)
    ind == 0 && error("@api unrecognized command: $cmd")

    lst, modules = _make_modules(exprs)

    if ind == 1 # use
        grplst = (:public, :define_public)
    elseif ind == 2 # test
        grplst = (:public, :define_public, :develop, :define_develop)
    elseif ind == 3 # extend
        grplst = (:define_public, :define_develop)
        for mod in modules, grp in (:base, :public, :develop)
            push!(lst, _make_exprs(:import, mod, grp))
        end
    else # export
        grplst = ()
        for mod in modules, grp in (:public, :define_public)
            push!(lst, :(eval(Expr( :export, $mod.__api__.$grp... ))))
        end
    end
    for mod in modules, grp in grplst
        push!(lst, _make_exprs(:using, mod, grp))
    end
    esc(Expr(:toplevel, lst...))
end

# We need Expr(:toplevel, (Expr($cmd, $mod, $sym) for sym in $mod.__api__.$grp)...)

function _make_list(cmd, mod, lst)
    isempty(lst) && return nothing
    @static if VERSION < v"0.7.0-DEV"
        length(lst) > 1 ?
            Expr(:toplevel, [Expr(cmd, mod, nam) for nam in lst]...) : Expr(cmd, mod, lst[1])
    else
        Expr(cmd, Expr(:(:), Expr(:., mod), [Expr(:., nam) for nam in lst]...))
    end
end

function _make_exprs(cmd, mod, grp)
    from = QuoteNode(grp == :base ? :Base : mod)
    :(eval($(Meta.parse("APITools._make_list($(QuoteNode(cmd)), $from, $mod.__api__.$grp)"))))
end

end # module APITools

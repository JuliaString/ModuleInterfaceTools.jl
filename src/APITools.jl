__precompile__(true)
"""
API Tools package

Copyright 2018 Gandalf Software, Inc., Scott P. Jones

Licensed under MIT License, see LICENSE.md

(@def macro "stolen" from DiffEqBase.jl/src/util.jl :-) )
"""
module APITools

const V6_COMPAT = VERSION < v"0.7.0-DEV"

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
    define_module::Vector{Symbol}
    TMP_API() = new(Symbol[], Symbol[], Symbol[], Symbol[], Symbol[], Symbol[])
end

const SymList = Tuple{Vararg{Symbol}}

struct API
    mod::Module
    base::SymList
    public::SymList
    develop::SymList
    define_public::SymList
    define_develop::SymList
    define_module::SymList

    API(mod, api::TMP_API) =
        new(mod,
            SymList(api.base), SymList(api.public), SymList(api.develop),
            SymList(api.define_public), SymList(api.define_develop), SymList(api.define_module))
end

const APIList = Tuple{Vararg{API}}

"""Expression to get current module"""
const _cur_mod = V6_COMPAT ? :( current_module() ) : :( @__MODULE__ )

"""
@api <cmd> [<symbols>...]

 * @api init             # set up module/package for adding names
 * @api freeze           # use at end of module, to "freeze" API

 * @api list   <modules>... # list API(s) of given modules

 * @api use    <modules>... # use for normal use
 * @api test   <modules>... # using api and dev, for testing purposes
 * @api extend <modules>... # for development, imports api & dev, use api & dev definitions
 * @api export <modules>... # export api symbols

 * @api base   <names...>  # Add functions from Base that are part of the API
 * @api public <names...>  # Add functions that are part of the public API
 * @api develop <names...> # Add functions that are part of the development API
 * @api define_public <names...> # Add other symbols that are part of the public API (structs, consts)
 * @api define_develop <names...> # Add other symbols that are part of the development API
 * @api define_module <names...> # Add submodule names that are part of the API
"""
macro api(cmd::Symbol)
    if cmd == :init
        quote
            export @api, APITools
            global __tmp_api__ = APITools.TMP_API()
            global __tmp_chain__ = Vector{APITools.API}[]
        end
    elseif cmd == :freeze
        esc(quote
            const __api__ = APITools.API($_cur_mod, __tmp_api__)
            push!(__tmp_chain__, __api__)
            const __chain__ = APITools.APIList(__tmp_chain__)
            __tmp_chain__ = _tmp_api__ = nothing
            end)
    elseif cmd == :list
        quote
            show(__api__)
            show(__tmp_chain__)
        end
    else
        error("@api unrecognized command: $cmd")
    end
end

const _cmduse = (:use, :test, :extend, :export)
const _cmdadd =
    (:define_module, :define_public, :define_develop, :public, :develop, :base, :maybe_public)

@static V6_COMPAT && (const _ff = findfirst)
@static V6_COMPAT || (_ff(lst, val) = coalesce(findfirst(isequal(val), lst), 0))

_add_def!(deflst, explst, sym) = (push!(deflst, sym); push!(explst, esc(:(function $sym end))))

"""Conditionally define functions, or import from Base"""
function _maybe_public(exprs)
    implst = Symbol[]
    deflst = Symbol[]
    explst = Expr[]
    for ex in exprs
        if isa(ex, Expr) && ex.head == :tuple
            for sym in ex.args
                isa(sym, Symbol) || error("@api $grp: $sym not a Symbol")
                isdefined(Base, sym) ? push!(implst, sym) : _add_def!(deflst, explst, sym)
            end
        elseif isa(ex, Symbol)
            isdefined(Base, ex) ? push!(implst, ex) : _add_def!(deflst, explst, ex)
        else
            error("@api $grp: syntax error $ex")
        end
    end
    lst = _add_symbols(:base, implst)
    isempty(deflst) && return lst
    Expr(:toplevel, lst, explst..., esc(:( append!(__tmp_api__.public, $deflst))))
end

function _add_symbols(grp, exprs)
    grp == :maybe_public && return _maybe_public(exprs)
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
    if grp == :base
        syms = SymList(symbols)
        expr = "APITools._make_list($(QuoteNode(:import)), $(QuoteNode(:Base)), $syms)"
        parsed = Meta.parse(expr)
        Expr(:toplevel,
             V6_COMPAT ? :(eval(current_module(), $parsed)) : :(eval(@__MODULE__, $parsed)),
             esc(:( append!(__tmp_api__.base, $symbols))))
    else
        esc(:( append!(__tmp_api__.$grp, $symbols) ))
    end
end

function _make_modules(exprs)
    uselst = Expr[]
    modlst = Symbol[]
    for ex in exprs
        if isa(ex, Expr) && ex.head == :tuple
            append!(modlst, ex.args)
            for sym in ex.args ; push!(uselst, :(using $sym)) ; end
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

    lst, modules = _make_modules(exprs)

    cmd == :export &&
        return esc(Expr(:toplevel, lst...,
                 [:(eval(Expr( :export, $mod.__api__.$grp... )))
                  for mod in modules, grp in (:define_module, :define_public, :public)]...))

    for mod in modules
        push!(lst, _make_module_exprs(mod))
    end

    if cmd == :use
        grplst = (:public, :define_public)
    elseif cmd == :test
        grplst = (:public, :develop, :define_public, :define_develop)
        push!(lst, V6_COMPAT ? :(using Base.Test) : :(using Test))
    elseif cmd == :extend
        grplst = (:define_public, :define_develop)
        for mod in modules, grp in (:base, :public, :develop)
            push!(lst, _make_exprs(:import, mod, grp))
        end
    else
        error("@api unrecognized command: $cmd")
    end
    for mod in modules, grp in grplst
        push!(lst, _make_exprs(:using, mod, grp))
    end
    esc(Expr(:toplevel, lst...))
end

# We need Expr(:toplevel, (Expr($cmd, $mod, $sym) for sym in $mod.__api__.$grp)...)

function _make_module_list(mod, lst)
    isempty(lst) && return nothing
    length(lst) == 1 ? :(import $mod.$(lst[1])) :
        Expr(:toplevel, [:(import $mod.$nam) for nam in lst]...)
end

_make_module_exprs(mod) =
 :(eval($(Meta.parse("APITools._make_module_list($(QuoteNode(mod)), $mod.__api__.define_module)"))))

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

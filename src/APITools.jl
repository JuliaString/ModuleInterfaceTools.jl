__precompile__(true)
"""
API Tools package

Copyright 2018 Gandalf Software, Inc., Scott P. Jones

Licensed under MIT License, see LICENSE.md

(@def macro "stolen" from DiffEqBase.jl/src/util.jl :-) )
"""
module APITools

const debug = Ref(false)

const V6_COMPAT = VERSION < v"0.7.0-DEV"
const BIG_ENDIAN = (ENDIAN_BOM == 0x01020304)

Base.parse(::Type{Expr}, args...; kwargs...) =
    Meta.parse(args...; kwargs...)

export @api, @def, V6_COMPAT, BIG_ENDIAN

macro def(name, definition)
    quote
        macro $(esc(name))()
            esc($(Expr(:quote, definition)))
        end
    end
end

const SymSet = Set{Symbol}

abstract type AbstractAPI end

struct TMP_API <: AbstractAPI
    mod::Module
    base::SymSet
    public::SymSet
    develop::SymSet
    public!::SymSet
    develop!::SymSet
    modules::SymSet

    TMP_API(mod::Module) = new(mod, SymSet(), SymSet(), SymSet(), SymSet(), SymSet(), SymSet())
end

const SymList = Tuple{Vararg{Symbol}}

struct API <: AbstractAPI
    mod::Module
    base::SymList
    public::SymList
    develop::SymList
    public!::SymList
    develop!::SymList
    modules::SymList
end

API(api::TMP_API) =
    API(api.mod, SymList(api.base), SymList(api.public), SymList(api.develop),
        SymList(api.public!), SymList(api.develop!), SymList(api.modules))

function Base.show(io::IO, api::AbstractAPI)
    println(io, "APITools.API: ", api.mod)
    for fld in (:base, :public, :develop, :public!, :develop!, :modules)
        syms = getfield(api, fld)
        isempty(syms) || println(fld, ": ", syms)
    end
end

"""Get current module"""
cur_mod() = ccall(:jl_get_current_module, Ref{Module}, ())

"""
@api <cmd> [<symbols>...]

 * @api freeze              # use at end of module, to "freeze" API

 * @api list   <modules>... # list API(s) of given modules (or current if none given)

 * @api use    <modules>... # use, without importing (i.e. can't extend)
 * @api test   <modules>... # using public and develop APIs, for testing purposes
 * @api extend <modules>... # for development, imports api & dev, use api & dev definitions
 * @api export <modules>... # export public definitions

 * @api base   <names...>  # Add functions from Base that are part of the API
 * @api public! <names...> # Add other symbols that are part of the public API (structs, consts)
 * @api develop! <names...> # Add other symbols that are part of the development API
 * @api public <names...>  # Add functions that are part of the public API
 * @api develop <names...> # Add functions that are part of the development API
 * @api modules <names...> # Add submodule names that are part of the API
"""
macro api(cmd::Symbol)
    mod = @static V6_COMPAT ? current_module() : __module__
    cmd == :list   ? _api_list(mod) :
    cmd == :freeze ? _api_freeze(mod) :
    error("@api unrecognized command: $cmd")
end

function _api_display(api::AbstractAPI)
    show(api)
    println()
end

function _api_list(mod::Module)
    isdefined(mod, :__api__) && _api_display(eval(mod, :__api__))
    isdefined(mod, :__tmp_api__) && _api_display(eval(mod, :__tmp_api__))
    nothing
end

function _api_freeze(mod::Module)
    ex = :( global const __api__ = APITools.API(__tmp_api__) ; __tmp_api__ = nothing )
    isdefined(mod, :__tmp_api__) && eval(mod, :( __tmp_api__ !== nothing ) ) && eval(mod, ex)
    nothing
end

const _cmduse = (:use, :test, :extend, :export, :list)
const _cmdadd =
    (:modules, :public, :develop, :public!, :develop!, :base, :base!)

@static V6_COMPAT && (const _ff = findfirst)
@static V6_COMPAT || (_ff(lst, val) = coalesce(findfirst(isequal(val), lst), 0))

function _add_def!(curmod, grp, exp)
    debug[] && print("_add_def!($curmod, $grp, $exp::$(typeof(exp))")
    if isa(exp, Symbol)
        sym = exp
    elseif isa(exp, AbstractString)
        sym = Symbol(exp)
    else
        error("@api $grp: syntax error $exp")
    end
    if isdefined(Base, sym)
        eval(curmod, :(import Base.$sym ))
        eval(curmod, :(push!(__tmp_api__.base, $(QuoteNode(sym)))))
    else
        eval(curmod, :(function $sym end))
        eval(curmod, :(push!(__tmp_api__.public!, $(QuoteNode(sym)))))
    end
end

"""Add symbols"""
function _add_symbols(curmod, grp, exprs)
    if debug[]
        print("_add_symbols($curmod, $grp, $exprs)")
        isdefined(curmod, :__tmp_api__) && print(" => ", eval(curmod, :__tmp_api__))
        println()
    end
    ex = :( export @api, APITools ; global __tmp_api__ = APITools.TMP_API($curmod) )
    isdefined(curmod, :__tmp_api__) || eval(curmod, ex)
    if grp == :base!
        for ex in exprs
            if isa(ex, Expr) && ex.head == :tuple
                for sym in ex.args
                    _add_def!(curmod, grp, sym)
                end
            else
                _add_def!(curmod, grp, ex)
            end
        end
    else
        symbols = SymSet()
        for ex in exprs
            if isa(ex, Expr) && ex.head == :tuple
                push!(symbols, ex.args...)
            elseif isa(ex, Symbol)
                push!(symbols, ex)
            elseif isa(ex, AbstractString)
                push!(symbols, Symbol(ex))
            else
                error("@api $grp: syntax error $ex")
            end
        end
        if grp == :base
            for sym in symbols
                eval(curmod, :( import Base.$sym ))
            end
        end
        for sym in symbols
            eval(curmod, :( push!(__tmp_api__.$grp, $(QuoteNode(sym)) )))
        end
    end
    debug[] && println("after add symbols: ", eval(curmod, :__tmp_api__))
    nothing
end

function _api_extend(curmod, modules)
    imp = :import
    use = :using

    for nam in modules
        mod = eval(curmod, nam)
        if isdefined(mod, :__api__)
            api = eval(mod, :__api__)
            _do_list(curmod, imp, api, :Base, :base)
            _do_list(curmod, imp, api, nam,   :public!)
            _do_list(curmod, imp, api, nam,   :develop!)
            _do_list(curmod, use, api, nam,   :public)
            _do_list(curmod, use, api, nam,   :develop)
        else
            println("API not found for module: $mod")
        end
    end

    nothing
end

function _api_use(curmod, modules)
    for nam in modules
        mod = eval(curmod, nam)
        if isdefined(mod, :__api__)
            api = eval(mod, :__api__)
            _do_list(curmod, :using, api, nam, :public)
            _do_list(curmod, :using, api, nam, :public!)
        end
    end
    nothing
end

_api_export(curmod, modules) =
    esc(Expr(:toplevel,
             [:(eval(Expr( :export, $mod.__api__.$grp... )))
              for mod in modules, grp in (:modules, :public, :public!)]...,
             nothing))

_api_list(curmod, modules) =
    Expr(:toplevel,
         [:(eval(APITools._api_display($mod))) for mod in modules]...,
         nothing)

function _api(curmod::Module, cmd::Symbol, exprs)
    ind = _ff(_cmdadd, cmd)
    ind == 0 || return _add_symbols(curmod, cmd, exprs)

    _ff(_cmduse, cmd) == 0 && error("Syntax error: @api $cmd $exprs")

    debug[] && print("_api($curmod, $cmd, $exprs)")
    modules = SymSet()
    for ex in exprs
        if isa(ex, Expr) && ex.head == :tuple
            push!(modules, ex.args...)
            for sym in ex.args ; eval(curmod, :(import $sym)) ; end
        elseif isa(ex, Symbol)
            push!(modules, ex)
            eval(curmod, :(import $ex))
        else
            error("@api $cmd: syntax error $ex")
        end
    end
    debug[] && println(" => $modules")

    cmd == :export && return _api_export(curmod, modules)
    cmd == :list && return _api_list(curmod, modules)

    for nam in modules
        mod = eval(curmod, nam)
        for sym in getfield(eval(mod, :__api__), :modules)
            eval(curmod, :(using $nam.$sym))
        end
    end

    # Be nice and set up standard Test
    cmd == :test && eval(curmod, V6_COMPAT ? :(using Base.Test) : :(using Test))

    cmd == :use ? _api_use(curmod, modules) : _api_extend(curmod, modules)
end

@static V6_COMPAT || (_dot_name(nam) = Expr(:., nam))

function _do_list(curmod, cmd, api, mod, grp)
    lst = getfield(api, grp)
    isempty(lst) && return
    @static if V6_COMPAT
        for nam in lst
            exp = Expr(cmd, mod, nam)
            debug[] && println("V6: $cmd, $mod, $mod, $exp")
            eval(curmod, exp)
        end
    else
        exp = Expr(cmd, Expr(:(:), _dot_name(mod), _dot_name.(lst)...))
        debug[] && println("V7: $cmd, $mod, $mod, $exp")
        try
            eval(curmod, exp)
        catch ex
            println("APITools: Error evaluating $exp")
            dump(exp)
            println(sprint(showerror, ex, catch_backtrace()))
        end
    end
end

macro api(cmd::Symbol, exprs...)
    @static V6_COMPAT ? _api(current_module(), cmd, exprs) : _api(__module__, cmd, exprs)
end

end # module APITools

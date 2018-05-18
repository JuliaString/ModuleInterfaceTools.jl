__precompile__(true)
"""
API Tools package

Copyright 2018 Gandalf Software, Inc., Scott P. Jones

Licensed under MIT License, see LICENSE.md

(@def macro "stolen" from DiffEqBase.jl/src/util.jl :-) )
"""
module APITools

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
    define_public::SymSet
    define_develop::SymSet
    define_module::SymSet

    TMP_API(mod::Module) = new(mod, SymSet(), SymSet(), SymSet(), SymSet(), SymSet(), SymSet())
end

const SymList = Tuple{Vararg{Symbol}}

struct API <: AbstractAPI
    mod::Module
    base::SymList
    public::SymList
    develop::SymList
    define_public::SymList
    define_develop::SymList
    define_module::SymList
end

API(api::TMP_API) =
    API(api.mod, SymList(api.base), SymList(api.public),
        SymList(api.develop), SymList(api.define_public),
        SymList(api.define_develop), SymList(api.define_module))

function Base.show(io::IO, api::AbstractAPI)
    println(io, "APITools.API: ", api.mod)
    for fld in (:base, :public, :develop, :define_public, :define_develop, :define_module)
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
    mod = @static V6_COMPAT ? current_module() : __module__
    cmd == :list   ? _api_list(mod) :
    cmd == :init   ? _api_init(mod) :
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

function _api_init(mod::Module)
    ex = :( export @api, APITools ; global __tmp_api__ = APITools.TMP_API($mod) )
    isdefined(mod, :__tmp_api__) || eval(mod, ex)
    nothing
end

function _api_freeze(mod::Module)
    ex = :( global const __api__ = APITools.API(__tmp_api__) ; __tmp_api__ = nothing )
    isdefined(mod, :__tmp_api__) && eval(mod, :( __tmp_api__ !== nothing ) ) && eval(mod, ex)
    nothing
end

const _cmduse = (:use, :test, :extend, :export)
const _cmdadd =
    (:define_module, :define_public, :define_develop, :public, :develop, :base, :maybe_public)

@static V6_COMPAT && (const _ff = findfirst)
@static V6_COMPAT || (_ff(lst, val) = coalesce(findfirst(isequal(val), lst), 0))

function _add_def!(curmod, sym)
    if isdefined(Base, sym)
        eval(curmod, :(push!(__tmp_api__.base, $(QuoteNode(sym)))))
        eval(curmod, :(import Base.$sym ))
    else
        eval(curmod, :(push!(__tmp_api__.public, $(QuoteNode(sym)))))
        eval(curmod, :(function $sym end))
    end
end

"""Add symbols"""
function _add_symbols(curmod, grp, exprs)
    #print("_add_symbols($curmod, $grp, $exprs)", isdefined(curmod, :__tmp_api__))
    _api_init(curmod)
    if grp == :maybe_public
        for ex in exprs
            if isa(ex, Expr) && ex.head == :tuple
                for sym in ex.args
                    isa(sym, Symbol) || error("@api $grp: $sym not a Symbol")
                    _add_def!(curmod, sym)
                end
            elseif isa(ex, Symbol)
                _add_def!(curmod, ex)
            else
                error("@api $grp: syntax error $ex")
            end
        end
    else
        symbols = SymSet()
        for ex in exprs
            if isa(ex, Expr) && ex.head == :tuple
                push!(symbols, ex.args...)
            elseif isa(ex, Symbol)
                push!(symbols, ex)
            else
                error("@api $grp: syntax error $ex")
            end
        end
        #println("symbols: ", symbols)
        if grp == :base
            for sym in symbols
                eval(curmod, :( import Base.$sym ))
            end
        end
        for sym in symbols
            eval(curmod, :( push!(__tmp_api__.$grp, $(QuoteNode(sym)) )))
        end
    end
    nothing
end

function _make_modules(curmod, cmd, exprs)
    modlst = SymSet()
    for ex in exprs
        if isa(ex, Expr) && ex.head == :tuple
            push!(modlst, ex.args...)
            for sym in ex.args ; eval(curmod, :(import $sym)) ; end
        elseif isa(ex, Symbol)
            push!(modlst, ex)
            eval(curmod, :(import $ex))
        else
            error("@api $cmd: syntax error $ex")
        end
    end
    modlst
end

function _api(curmod::Module, cmd::Symbol, exprs)
    ind = _ff(_cmdadd, cmd)
    ind == 0 || return _add_symbols(curmod, cmd, exprs)

    ind = _ff(_cmduse, cmd)

    modules = _make_modules(curmod, cmd, exprs)

    cmd == :export &&
        return esc(Expr(:toplevel,
                        [:(eval(Expr( :export, $mod.__api__.$grp... )))
                         for mod in modules, grp in (:define_module, :define_public, :public)]...,
                        nothing))
    cmd == :list &&
        return Expr(:toplevel,
                    [:(eval(APITools._api_display($mod))) for mod in modules]...,
                    nothing)

    lst = Expr[]
    for mod in modules
        exp = "APITools._make_module_list($(QuoteNode(mod)), $mod.__api__.define_module)"
        push!(lst, :(eval($(Meta.parse(exp)))))
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
    esc(Expr(:toplevel, lst..., nothing))
end

@static if V6_COMPAT
    macro api(cmd::Symbol, exprs...) ; _api(current_module(), cmd, exprs) ; end
else
    macro api(cmd::Symbol, exprs...) ; _api(__module__, cmd, exprs) ; end
end

function _make_module_list(mod, lst)
    isempty(lst) && return nothing
    length(lst) == 1 ? :(import $mod.$(lst[1])) :
        Expr(:toplevel, [:(import $mod.$nam) for nam in lst]..., nothing)
end

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

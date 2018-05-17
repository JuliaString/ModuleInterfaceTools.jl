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
    cmd == :init && return _api_init()
    cmd == :freeze && return esc(_api_freeze())
    cmd == :list && return _api_list()
    error("@api unrecognized command: $cmd")
end

function _api_display(api, chain)
    show(api)
    println()
    show(chain)
    println()
end

function _api_display(mod)
    isdefined(mod, :__api__) &&
        _api_display(eval(mod, :__api__), eval(mod, :__chain__))
    isdefined(mod, :__tmp_api__) &&
        _api_display(eval(mod, :__tmp_api__), eval(mod, :__tmp_chain__))
    nothing
end

_api_freeze(mod, api, chain) = APIList(push!(chain, API(mod, api)))

_api_init() =
    quote
        export @api, APITools
        global __tmp_api__ = APITools.TMP_API()
        global __tmp_chain__ = APITools.API[]
    end

_api_freeze() =
    quote
        global const __chain__ = APITools._api_freeze($_cur_mod, __tmp_api__, __tmp_chain__)
        global const __api__ = __chain__[end]
        __tmp_chain__ = __tmp_api__ = nothing
    end

_api_list(mod = _cur_mod) = :( APITools._api_display($mod) )

const _cmduse = (:use, :test, :extend, :export)
const _cmdadd =
    (:define_module, :define_public, :define_develop, :public, :develop, :base, :maybe_public)

@static V6_COMPAT && (const _ff = findfirst)
@static V6_COMPAT || (_ff(lst, val) = coalesce(findfirst(isequal(val), lst), 0))

function _add_def!(deflst, implst, explst, sym)
    if isdefined(Base, sym)
        push!(implst, sym)
    else
        push!(deflst, sym)
        push!(explst, esc(:(function $sym end)))
    end
end

"""Add symbols"""
function _add_symbols(grp, exprs)
    print("_add_symbols($grp, $exprs)")
    outlst = Expr[:(isdefined($_cur_mod, :__tmp_api__) || APITools._api_init())]
    println(" => ", outlst)
    outlst = Expr[]
    if grp == :maybe_public
        implst = Symbol[]
        deflst = Symbol[]
        for ex in exprs
            if isa(ex, Expr) && ex.head == :tuple
                for sym in ex.args
                    isa(sym, Symbol) || error("@api $grp: $sym not a Symbol")
                    _add_def!(deflst, implst, outlst, sym)
                end
            elseif isa(ex, Symbol)
                _add_def!(deflst, implst, outlst, ex)
            else
                error("@api $grp: syntax error $ex")
            end
        end
        isempty(deflst) ||
            push!(outlst, Expr(:call, :push!,
                               Expr(:., :__tmp_api__, QuoteNode(:public)),
                               QuoteNode.(deflst)...))
        exprs = implst
        grp = :base
    end
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
    println("symbols: ", symbols)
    if grp == :base
        syms = SymList(symbols)
        expr = "APITools._make_list($(QuoteNode(:import)), $(QuoteNode(:Base)), $syms)"
        push!(outlst, esc(:(eval($_cur_mod, $(Meta.parse(expr))))))
    end
    push!(outlst, Expr(:call, :push!,
                       Expr(:., :__tmp_api__, QuoteNode(grp)), QuoteNode.(symbols)...))
    println(outlst)
    outlst
end

function _make_modules(cmd, exprs)
    uselst = Expr[]
    modlst = Symbol[]
    for ex in exprs
        if isa(ex, Expr) && ex.head == :tuple
            append!(modlst, ex.args)
            for sym in ex.args ; push!(uselst, :(import $sym)) ; end
        elseif isa(ex, Symbol)
            push!(modlst, ex)
            push!(uselst, :(import $ex))
        else
            error("@api $cmd: syntax error $ex")
        end
    end
    uselst, modlst
end

function _api(cmd, exprs)
    ind = _ff(_cmdadd, cmd)
    ind == 0 || return esc(Expr(:toplevel, _add_symbols(cmd, exprs), nothing))

    ind = _ff(_cmduse, cmd)

    lst, modules = _make_modules(cmd, exprs)

    cmd == :export &&
        return esc(Expr(:toplevel, lst...,
                        [:(eval($_cur_mod, Expr( :export, $mod.__api__.$grp... )))
                         for mod in modules, grp in (:define_module, :define_public, :public)]...,
                        nothing))
    cmd == :list &&
        return Expr(:toplevel,
                    [:(eval($_cur_mod, APITools._api_display($mod))) for mod in modules]...,
                    nothing)

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
        # should add unique modules to __tmp_chain__
        for mod in modules
            push!(lst,
                  esc(:(in($mod.__api__, __tmp_chain__) || push!(__tmp_chain__, $mod.__api__))))
        end
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

macro api(cmd::Symbol, exprs...) ; _api(cmd, exprs) ; end

# We need Expr(:toplevel, (Expr($cmd, $mod, $sym) for sym in $mod.__api__.$grp)...)

function _make_module_list(mod, lst)
    isempty(lst) && return nothing
    length(lst) == 1 ? :(import $mod.$(lst[1])) :
        Expr(:toplevel, [:(import $mod.$nam) for nam in lst]..., nothing)
end

_make_module_exprs(mod) =
 :(eval($_cur_mod, $(Meta.parse("APITools._make_module_list($(QuoteNode(mod)), $mod.__api__.define_module)"))))

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
    :(eval($_cur_mod,
           $(Meta.parse("APITools._make_list($(QuoteNode(cmd)), $from, $mod.__api__.$grp)"))))
end

end # module APITools

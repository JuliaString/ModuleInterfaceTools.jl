__precompile__(true)
"""
API Tools package

Copyright 2018-2019 Gandalf Software, Inc., Scott P. Jones

Licensed under MIT License, see LICENSE.md

(@def macro "stolen" from DiffEqBase.jl/src/util.jl :-) )
"""
module ModuleInterfaceTools

const debug = Ref(false)
const showeval = Ref(false)

const V6_COMPAT = VERSION < v"0.7-"
const BIG_ENDIAN = (ENDIAN_BOM == 0x01020304)

_stdout() = stdout
_stderr() = stderr

Base.parse(::Type{Expr}, args...; kwargs...) =
    Meta.parse(args...; kwargs...)

export @api, V6_COMPAT, BIG_ENDIAN

_api_def(name, definition) =
    quote
        macro $(esc(name))()
            esc($(Expr(:quote, definition)))
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
    println(io, "ModuleInterfaceTools.API: ", api.mod)
    for fld in (:base, :public, :develop, :public!, :develop!, :modules)
        syms = getfield(api, fld)
        isempty(syms) && continue
        print(fld, ":")
        for s in syms
            print(" ", s)
        end
        println()
        println()
    end
end

function m_eval(mod, expr)
    try
        showeval[] && println("m_eval($mod, $expr)")
        Core.eval(mod, expr)
    catch ex
        println("m_eval($mod, $expr)");
        println(sprint(showerror, ex, catch_backtrace()))
        #rethrow(ex)
    end
end

"""
@api <cmd> [<symbols>...]

 * freeze                # use at end of module to freeze API

 * list     <modules>... # list API(s) of given modules (or current if none given)

 * use      <modules>... # use, without importing (i.e. can't extend)
 * use!     <modules>... # use, without importing (i.e. can't extend), "export"
 * test     <modules>... # using public and develop APIs, for testing purposes
 * extend   <modules>... # for development, imports api & dev, use api & dev definitions
 * extend!  <modules>... # for development, imports api & dev, use api & dev definitions, "export"
 * reexport <modules>... # export public definitions from those modules

 * base     <names...>   # Add functions from Base that are part of the API (extendible)
 * base!    <names...>   # Add functions from Base or define them if not in Base
 * public   <names...>   # Add other symbols that are part of the public API (structs, consts)
 * public!  <names...>   # Add functions that are part of the public API (extendible)
 * develop  <names...>   # Add other symbols that are part of the development API
 * develop! <names...>   # Add functions that are part of the development API (extendible)
 * define!  <names...>   # Define functions to be extended, public API
 * defdev!  <names...>   # Define functions to be extended, develop API
 * modules  <names...>   # Add submodule names that are part of the API

 * path     <paths...>  # Add paths to LOAD_PATH

 * def <name> <expr>    # Same as the @def macro, creates a macro with the given name

"""
macro api(cmd::Symbol)
    mod = __module__
    cmd == :list   ? _api_list(mod) :
    cmd == :freeze ? _api_freeze(mod) :
    cmd == :test   ? _api_test(mod) :
    error("@api unrecognized command: $cmd")
end

function _api_display(mod, nam)
    if isdefined(mod, nam) && (api = m_eval(mod, nam)) !== nothing
        show(api);
    else
        println("Exported from $mod:")
        syms = names(mod)
        if !isempty(syms)
            print(fld, ":")
            for s in syms
                print(" ", s)
            end
        end
    end
    println()
end

_api_list(mod::Module) = (_api_display(mod, :__api__) ; _api_display(mod, :__tmp_api__))

function _api_freeze(mod::Module)
    ex = :( const __api__ = ModuleInterfaceTools.API(__tmp_api__) ; __tmp_api__ = nothing )
    isdefined(mod, :__tmp_api__) && m_eval(mod, :( __tmp_api__ !== nothing ) ) && m_eval(mod, ex)
    nothing
end

function _api_path(curmod, exprs)
    for exp in exprs
        if isa(exp, Expr) || isa(exp, Symbol)
            str = m_eval(curmod, exp)
        elseif isa(exp, String)
            str = exp
        else
            error("@api path: syntax error $exp")
        end
        m_eval(curmod, :( push!(LOAD_PATH, $str) ))
    end
    nothing
end

const _cmduse = (:use, :use!, :test, :extend, :extend!, :reexport, :list)
const _cmdadd =
    (:modules, :public, :develop, :public!, :develop!, :base, :base!, :define!, :defdev!)

_ff(lst, val) = (ret = findfirst(isequal(val), lst); ret === nothing ? 0 : ret)

function _add_def!(curmod, grp, exp)
    debug[] && print("_add_def!($curmod, $grp, $exp::$(typeof(exp))")
    if isa(exp, Symbol)
        sym = exp
    elseif isa(exp, AbstractString)
        sym = Symbol(exp)
    else
        error("@api $grp: syntax error $exp")
    end
    if grp == :base! && isdefined(Base, sym)
        m_eval(curmod, :(import Base.$sym ))
        m_eval(curmod, :(push!(__tmp_api__.base, $(QuoteNode(sym)))))
        return
    end
    m_eval(curmod, :(function $sym end))
    m_eval(curmod, (grp == :defdev!
                    ? :(push!(__tmp_api__.develop!, $(QuoteNode(sym))))
                    : :(push!(__tmp_api__.public!,  $(QuoteNode(sym))))))
end

function push_args!(symbols, lst, grp)
    for ex in lst
        if isa(ex, Expr) && ex.head == :tuple
            push_args!(symbols, ex.args)
        elseif isa(ex, Symbol)
            push!(symbols, ex)
        elseif isa(ex, AbstractString)
            push!(symbols, Symbol(ex))
        else
            error("@api $grp: syntax error $ex")
        end
    end
end

"""Initialize the temp api variable for this module"""
_init_api(curmod) =
    isdefined(curmod, :__tmp_api__) ||
        m_eval(curmod, :( global __tmp_api__ = ModuleInterfaceTools.TMP_API($curmod)))

"""Add symbols"""
function _add_symbols(curmod, grp, exprs)
    if debug[]
        print("_add_symbols($curmod, $grp, $exprs)")
        isdefined(curmod, :__tmp_api__) && print(" => ", m_eval(curmod, :__tmp_api__))
        println()
    end
    _init_api(curmod)
    if grp == :base! || grp == :define! || grp == :defdev!
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
                push_args!(symbols, ex.args, grp)
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
                m_eval(curmod, :( import Base.$sym ))
            end
        end
        for sym in symbols
            m_eval(curmod, :( push!(__tmp_api__.$grp, $(QuoteNode(sym)) )))
        end
    end
    debug[] && println("after add symbols: ", m_eval(curmod, :__tmp_api__))
    nothing
end

has_api(mod) = isdefined(mod, :__api__)
get_api(curmod, mod) = m_eval(curmod, :( $mod.__api__ ))

function _api_extend(curmod, modules, cpy::Bool)
    for nam in modules
        mod = m_eval(curmod, nam)
        if has_api(mod)
            api = get_api(curmod, mod)
            _do_list(curmod, cpy, :import, Base, :Base, :base,  api)
            _do_list(curmod, cpy, :import, mod, nam, :public!,  api)
            _do_list(curmod, cpy, :import, mod, nam, :develop!, api)
            _do_list(curmod, cpy, :using,  mod, nam, :public,   api)
            _do_list(curmod, cpy, :using,  mod, nam, :develop,  api)
        else
            _do_list(curmod, cpy, :import, mod, nam, :public!,  names(mod))
        end
    end
    nothing
end

function _api_use(curmod, modules, cpy::Bool)
    for nam in modules
        mod = m_eval(curmod, nam)
        if has_api(mod)
            api = get_api(curmod, mod)
            _do_list(curmod, cpy, :using, mod, nam, :public,  api)
            _do_list(curmod, cpy, :using, mod, nam, :public!, api)
        else
            _do_list(curmod, cpy, :using, mod, nam, :public!, names(mod))
        end
    end
    nothing
end

function _api_reexport(curmod, modules)
    for nam in modules
        mod = m_eval(curmod, nam)
        if has_api(mod)
            api = get_api(curmod, mod)
            m_eval(curmod, Expr( :export, getfield(api, :modules)...))
            m_eval(curmod, Expr( :export, getfield(api, :public)...))
            m_eval(curmod, Expr( :export, getfield(api, :public!)...))
        end
    end
    nothing
end

function _api_list(curmod, modules)
    for nam in modules
        _api_list(m_eval(curmod, nam))
    end
    nothing
end

_api_test(mod) = m_eval(mod, :(using Test))

function _api(curmod::Module, cmd::Symbol, exprs)
    cmd == :def && return _api_def(exprs...)
    cmd == :path && return _api_path(curmod, exprs)

    ind = _ff(_cmdadd, cmd)
    ind == 0 || return _add_symbols(curmod, cmd, exprs)

    _ff(_cmduse, cmd) == 0 && error("Syntax error: @api $cmd $exprs")

    debug[] && print("_api($curmod, $cmd, $exprs)")

    # Be nice and set up standard Test
    cmd == :test && _api_test(curmod)

    modules = SymSet()
    for ex in exprs
        if isa(ex, Expr) && ex.head == :tuple
            # Some of these might not just be modules
            # might have module(symbols, !syms, sym => other), need to add support for that
            for sym in ex.args
                if isa(sym, Symbol)
                    push!(modules, sym)
                    m_eval(curmod, :(import $sym))
                else
                    println("Not a symbol: $sym");
                    dump(sym);
                end
            end
        elseif isa(ex, Symbol)
            push!(modules, ex)
            m_eval(curmod, :(import $ex))
        else
            error("@api $cmd: syntax error $ex")
        end
    end
    debug[] && println(" => $modules")

    cmd == :reexport && return _api_reexport(curmod, modules)
    cmd == :list && return _api_list(curmod, modules)

    cpy = (cmd == :use!) || (cmd == :extend!)
    cpy && _init_api(curmod)

    for nam in modules
        mod = m_eval(curmod, nam)
        if has_api(mod)
            api = get_api(curmod, mod)
            for sym in getfield(api, :modules)
                if isdefined(mod, sym)
                    m_eval(curmod, :(using $nam.$sym))
                    cpy && m_eval(curmod, :( push!(__tmp_api__.modules, $(QuoteNode(sym)) )))
                else
                    println(_stderr(), "Warning: Exported symbol $sym is not defined in $nam")
                end
            end
        end
    end

    ((cmd == :use || cmd == :use!)
     ? _api_use(curmod, modules, cpy)
     : _api_extend(curmod, modules, cpy))
end

function makecmd(cmd, nam, sym)
    (cmd == :using
     ? Expr(cmd, Expr(:(:), Expr(:., nam), Expr(:., sym)))
     : Expr(cmd, Expr(:., nam, sym)))
end

_do_list(curmod, cpy, cmd, mod, nam, grp, api::API) =
    _do_list(curmod, cpy, cmd, mod, nam, grp, getfield(api, grp))

function _do_list(curmod, cpy, cmd, mod, nam, grp, lst)
    debug[] && println("_do_list($curmod, $cpy, $cmd, $mod, $nam, $grp, $lst)")
    for sym in lst
        if isdefined(mod, sym)
            m_eval(curmod, makecmd(cmd, nam, sym))
            cpy && m_eval(curmod, :( push!(__tmp_api__.$grp, $(QuoteNode(sym)) )))
        else
            println(_stderr(), "Warning: Exported symbol $sym is not defined in $nam")
        end
    end
end

macro api(cmd::Symbol, exprs...)
    _api(__module__, cmd, exprs)
end

end # module ModuleInterfaceTools

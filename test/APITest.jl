module APITest
using APITools

_printapi(C) = (print(C) ; isdefined(APITest, :__tmp_api__) ? (show(__tmp_api__) ; println()) : println("Not defined"))
macro printapi() ; _printapi("C: ") ; :( _printapi("R: ") ) ; end
_printsym(C) = println(C, names(APITest, true, true))
macro printsym() ; _printsym("C: ") ; :( _printsym("R: ") ) ; end

#@printsym

#@printapi

#println(macroexpand( :( @api init ) ))

@api init

#@printapi

#println(macroexpand( :( @api base nextind, getindex, setindex! ) ) )

@api base nextind, getindex, setindex!

#@printapi

#println(macroexpand( :( @api public myfunc ) ) )

@api public myfunc

#println(macroexpand( :( @api define_public Foo )))

@api define_public Foo

struct Foo end

function myfunc end
myfunc(::Integer) = 1
myfunc(::String)  = 2

#@printapi()

#println(macroexpand( :( @api freeze ) ))

@api freeze

#@printsym

end # module APITest

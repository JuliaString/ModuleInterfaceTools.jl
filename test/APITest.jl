module APITest
using APITools

@api init

@api base nextind, getindex, setindex!

println(__tmp_api__)

@api public myfunc
@api define_public Foo

struct Foo end

function myfunc end
myfunc(::Integer) = 1
myfunc(::String)  = 2

#println(__tmp_api__)

#println(macroexpand( :( @api freeze ) ))

@api freeze

end # module APITest

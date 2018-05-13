module APITest
using APITools
@api init
@api base nextind, getindex, setindex!
@api public myfunc
@api define_public Foo

struct Foo end

function myfunc end
myfunc(::Integer) = 1
myfunc(::String)  = 2

@api freeze
end # module APITest
